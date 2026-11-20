//! Wire protocol and safety rules shared by the app and the privileged helper.
//! Requests and responses are newline-delimited JSON over a Unix socket.
use serde::{Deserialize, Serialize};

pub const SOCKET_PATH: &str = "/var/run/core-monitor.smc-helper.sock";
pub const DEFAULT_LABEL: &str = "ventaphobia.smc-helper";
pub const CONSERVATIVE_MIN_RPM: i64 = 1_000;
pub const CONSERVATIVE_MAX_RPM: i64 = 6_500;
pub const RENEW_INTERVAL_SECONDS: f64 = 5.0;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "camelCase")]
pub enum Request {
    Read { key: String },
    Renew,
    SetManual { fan: i64, rpm: i64 },
    SetAuto { fan: i64 },
    Metadata,
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Response {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub value: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mode_key_template: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub has_force_test_key: Option<bool>,
}

impl Response {
    pub fn ok() -> Self {
        Self { ok: true, ..Default::default() }
    }
    pub fn value(value: f64) -> Self {
        Self { ok: true, value: Some(value), ..Default::default() }
    }
    pub fn error(message: impl Into<String>) -> Self {
        Self { ok: false, error: Some(message.into()), ..Default::default() }
    }
}

pub fn validate_fan_id(fan: i64) -> Result<usize, String> {
    if (0..=9).contains(&fan) {
        Ok(fan as usize)
    } else {
        Err("Fan ID must be between 0 and 9".into())
    }
}

pub fn validate_requested_rpm(rpm: i64) -> Result<i64, String> {
    if (500..=10_000).contains(&rpm) {
        Ok(rpm)
    } else {
        Err("RPM must be between 500 and 10000".into())
    }
}

/// Requested RPM must sit inside the fan's reported range intersected with
/// the conservative bounds; it is rejected, not clamped, when it does not.
pub fn validated_hardware_rpm(fan: usize, requested: i64, reported_min: Option<i64>, reported_max: Option<i64>) -> Result<i64, String> {
    let (Some(rmin), Some(rmax)) = (reported_min.filter(|v| *v > 0), reported_max.filter(|v| *v > 0)) else {
        return Err(format!("Fan {fan} did not report safe RPM limits"));
    };
    let (min, max) = (rmin.max(CONSERVATIVE_MIN_RPM), rmax.min(CONSERVATIVE_MAX_RPM));
    if min > max {
        return Err(format!("Fan {fan} reported an unsafe RPM range"));
    }
    if !(min..=max).contains(&requested) {
        return Err(format!("RPM for fan {fan} must be between {min} and {max}"));
    }
    Ok(requested)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn request_wire_format() {
        let json = serde_json::to_string(&Request::SetManual { fan: 1, rpm: 2400 }).unwrap();
        assert_eq!(json, r#"{"op":"setManual","fan":1,"rpm":2400}"#);
        assert_eq!(serde_json::from_str::<Request>(r#"{"op":"renew"}"#).unwrap(), Request::Renew);
        assert!(serde_json::from_str::<Request>(r#"{"op":"exec","cmd":"rm"}"#).is_err());
    }

    #[test]
    fn rpm_safety() {
        assert!(validate_fan_id(10).is_err() && validate_fan_id(-1).is_err() && validate_fan_id(9).is_ok());
        assert!(validate_requested_rpm(499).is_err() && validate_requested_rpm(10_001).is_err());
        assert_eq!(validated_hardware_rpm(0, 2000, Some(1200), Some(7000)), Ok(2000));
        assert!(validated_hardware_rpm(0, 6600, Some(1200), Some(7000)).is_err());
        assert!(validated_hardware_rpm(0, 1100, Some(1200), Some(5000)).is_err());
        assert!(validated_hardware_rpm(0, 2000, None, Some(5000)).is_err());
        assert!(validated_hardware_rpm(0, 2000, Some(7000), Some(6800)).is_err());
    }
}
