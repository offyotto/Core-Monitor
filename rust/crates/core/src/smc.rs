//! Encoding and decoding of AppleSMC key values.

pub const KERNEL_INDEX_SMC: u32 = 2;
pub const CMD_READ_BYTES: u8 = 5;
pub const CMD_WRITE_BYTES: u8 = 6;
pub const CMD_READ_KEY_INFO: u8 = 9;

pub const fn four_cc(key: &[u8; 4]) -> u32 {
    ((key[0] as u32) << 24) | ((key[1] as u32) << 16) | ((key[2] as u32) << 8) | key[3] as u32
}

/// Packs up to the first four bytes of `key`, matching `fourCharCodeFrom`.
pub fn four_cc_str(key: &str) -> u32 {
    key.bytes()
        .take(4)
        .enumerate()
        .fold(0u32, |acc, (i, b)| acc | ((b as u32) << (8 * (3 - i))))
}

pub const TYPE_FLT: u32 = four_cc(b"flt ");
pub const TYPE_IOFT: u32 = four_cc(b"ioft");
pub const TYPE_SP78: u32 = four_cc(b"sp78");
pub const TYPE_FPE2: u32 = four_cc(b"fpe2");
pub const TYPE_UI8: u32 = four_cc(b"ui8 ");
pub const TYPE_UI16: u32 = four_cc(b"ui16");
pub const TYPE_UI32: u32 = four_cc(b"ui32");
pub const TYPE_SI16: u32 = four_cc(b"si16");

/// Layout-compatible with the kernel's `SMCKeyData_t`.
#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
pub struct SmcVersion {
    pub major: u8,
    pub minor: u8,
    pub build: u8,
    pub reserved: u8,
    pub release: u16,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
pub struct SmcPLimitData {
    pub version: u16,
    pub length: u16,
    pub cpu_p_limit: u32,
    pub gpu_p_limit: u32,
    pub mem_p_limit: u32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct SmcKeyInfo {
    pub data_size: u32,
    pub data_type: u32,
    pub data_attributes: u8,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
pub struct SmcParam {
    pub key: u32,
    pub vers: SmcVersion,
    pub p_limit_data: SmcPLimitData,
    pub key_info: SmcKeyInfo,
    pub result: u8,
    pub status: u8,
    pub data8: u8,
    pub data32: u32,
    pub bytes: [u8; 32],
}

/// A key is exactly four printable ASCII characters.
pub fn validate_key(key: &str) -> Result<&str, String> {
    let bytes = key.as_bytes();
    if bytes.len() == 4 && bytes.iter().all(|b| (0x20..=0x7E).contains(b)) {
        Ok(key)
    } else {
        Err("SMC key must be exactly 4 printable ASCII characters".into())
    }
}

pub fn decode_ioft(raw: &[u8], data_size: u32) -> Option<f64> {
    if data_size != 8 || raw.len() < 8 {
        return None;
    }
    let value = raw[..8].iter().rev().fold(0u64, |acc, b| (acc << 8) | *b as u64);
    Some(value as f64 / 65_536.0)
}

/// Decodes a value the way the monitor does, including its 2-byte fallback.
pub fn decode(raw: &[u8; 32], key: Option<&str>, data_type: u32, data_size: u32) -> Option<f64> {
    let be16 = || ((raw[0] as u16) << 8) | raw[1] as u16;
    match (data_type, data_size) {
        (TYPE_FLT, 4) => return decode_float(&raw[..4], key),
        (TYPE_IOFT, _) => return decode_ioft(raw, data_size),
        (TYPE_SP78, 2) => return Some(be16() as i16 as f64 / 256.0),
        (TYPE_FPE2, 2) => return Some((((raw[0] as u32) << 6) + ((raw[1] as u32) >> 2)) as f64),
        (TYPE_UI8, 1) => return Some(raw[0] as f64),
        (TYPE_UI16, 2) => return Some(be16() as f64),
        (TYPE_UI32, 4) => return Some(u32::from_be_bytes([raw[0], raw[1], raw[2], raw[3]]) as f64),
        (TYPE_SI16, 2) => return Some(be16() as i16 as f64),
        _ => {}
    }
    if data_size == 2 {
        return Some(be16() as f64);
    }
    None
}

/// Strict decoder used by the privileged helper: no generic fallbacks.
pub fn decode_strict(raw: &[u8; 32], key: Option<&str>, data_type: u32, data_size: u32) -> Option<f64> {
    match (data_type, data_size) {
        (TYPE_SP78, 2) | (TYPE_FPE2, 2) | (TYPE_UI8, 1) | (TYPE_UI16, 2) | (TYPE_FLT, 4) | (TYPE_IOFT, 8) => {
            decode(raw, key, data_type, data_size)
        }
        _ => None,
    }
}

fn preferred_float_range(key: Option<&str>) -> Option<(f64, f64)> {
    let key = key?;
    if key.len() == 4 && key.starts_with('F') && ["Ac", "Mn", "Mx", "Tg"].contains(&&key[2..]) {
        return Some((100.0, 10_000.0));
    }
    None
}

/// SMC floats are little-endian on Apple Silicon but some keys are reported
/// big-endian; pick the plausible interpretation.
pub fn decode_float(raw: &[u8], key: Option<&str>) -> Option<f64> {
    if raw.len() < 4 {
        return None;
    }
    let be = f32::from_be_bytes([raw[0], raw[1], raw[2], raw[3]]) as f64;
    let le = f32::from_le_bytes([raw[0], raw[1], raw[2], raw[3]]) as f64;
    let valid = |v: f64| v.is_finite() && v.abs() < 100_000.0;
    match (valid(be), valid(le)) {
        (true, false) => return Some(be),
        (false, true) => return Some(le),
        (false, false) => return None,
        (true, true) => {}
    }
    if let Some((lo, hi)) = preferred_float_range(key) {
        let (bp, lp) = ((lo..=hi).contains(&be), (lo..=hi).contains(&le));
        if bp != lp {
            return Some(if bp { be } else { le });
        }
    }
    let subnormal = |v: f64| v != 0.0 && v.abs() < 1e-12;
    if subnormal(be) != subnormal(le) {
        return Some(if subnormal(be) { le } else { be });
    }
    let common = |v: f64| v == 0.0 || (0.01..=20_000.0).contains(&v.abs());
    if common(be) != common(le) {
        return Some(if common(be) { be } else { le });
    }
    Some(if be.abs() >= le.abs() { be } else { le })
}

/// Encodes an integer for an SMC write.
pub fn encode(value: i64, data_type: u32, data_size: u32) -> Result<[u8; 32], String> {
    let mut raw = [0u8; 32];
    if data_type == TYPE_UI8 && data_size >= 1 {
        raw[0] = value.clamp(0, 255) as u8;
    } else if data_type == TYPE_UI16 && data_size >= 2 {
        raw[..2].copy_from_slice(&(value.clamp(0, u16::MAX as i64) as u16).to_be_bytes());
    } else if data_type == TYPE_FPE2 && data_size >= 2 {
        let v = value.clamp(0, 16383) as u16;
        raw[0] = ((v >> 6) & 0xFF) as u8;
        raw[1] = ((v & 0x3F) << 2) as u8;
    } else if data_type == TYPE_FLT && data_size >= 4 {
        raw[..4].copy_from_slice(&(value as f32).to_le_bytes());
    } else {
        return Err("Unsupported write type for key".into());
    }
    Ok(raw)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn bytes(prefix: &[u8]) -> [u8; 32] {
        let mut raw = [0u8; 32];
        raw[..prefix.len()].copy_from_slice(prefix);
        raw
    }

    #[test]
    fn four_cc_matches_swift_packing() {
        assert_eq!(four_cc_str("FNum"), 0x464E_756D);
        assert_eq!(four_cc(b"flt "), four_cc_str("flt "));
    }

    #[test]
    fn decodes_fixed_point_types() {
        assert_eq!(decode(&bytes(&[0x2A, 0x80]), None, TYPE_SP78, 2), Some(42.5));
        assert_eq!(decode(&bytes(&[0x1F, 0x40]), None, TYPE_FPE2, 2), Some(2000.0));
        assert_eq!(decode(&bytes(&[0xFF, 0xFE]), None, TYPE_SI16, 2), Some(-2.0));
        assert_eq!(decode(&bytes(&[0x00, 0x05]), None, four_cc(b"zzzz"), 2), Some(5.0));
        assert_eq!(decode_strict(&bytes(&[0x00, 0x05]), None, four_cc(b"zzzz"), 2), None);
    }

    #[test]
    fn decodes_ioft() {
        let raw = bytes(&[0x00, 0x00, 0x2A, 0x00, 0, 0, 0, 0]);
        assert_eq!(decode(&raw, None, TYPE_IOFT, 8), Some(42.0));
        assert_eq!(decode_ioft(&raw, 4), None);
    }

    #[test]
    fn float_prefers_little_endian_rpm() {
        let raw = 2400.0f32.to_le_bytes();
        assert_eq!(decode_float(&raw, Some("F0Ac")), Some(2400.0));
        let raw = 55.5f32.to_be_bytes();
        assert_eq!(decode_float(&raw, Some("Tp01")), Some(55.5));
    }

    #[test]
    fn encode_round_trips() {
        let raw = encode(2000, TYPE_FPE2, 2).unwrap();
        assert_eq!(decode(&raw, None, TYPE_FPE2, 2), Some(2000.0));
        let raw = encode(3100, TYPE_FLT, 4).unwrap();
        assert_eq!(decode(&raw, Some("F0Tg"), TYPE_FLT, 4), Some(3100.0));
        assert_eq!(encode(1, TYPE_UI8, 1).unwrap()[0], 1);
        assert!(encode(1, TYPE_SP78, 2).is_err());
    }

    #[test]
    fn validates_keys() {
        assert!(validate_key("FNum").is_ok());
        assert!(validate_key("FS! ").is_ok());
        assert!(validate_key("F0A").is_err());
        assert!(validate_key("F0\u{7}c").is_err());
    }

    #[test]
    fn param_struct_matches_kernel_size() {
        assert_eq!(std::mem::size_of::<SmcParam>(), 80);
        assert_eq!(std::mem::offset_of!(SmcParam, result), 40);
        assert_eq!(std::mem::offset_of!(SmcParam, bytes), 48);
    }
}
