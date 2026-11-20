/// The SMC key format reserves one decimal character for the fan ID.
pub const MAXIMUM_FAN_COUNT: usize = 10;

pub fn supports(fan_id: i64) -> bool {
    (0..MAXIMUM_FAN_COUNT as i64).contains(&fan_id)
}

pub fn validated_count(value: Option<f64>) -> Option<usize> {
    let v = value?;
    (v.is_finite() && v > 0.0 && v <= MAXIMUM_FAN_COUNT as f64 && v.trunc() == v)
        .then_some(v as usize)
}

/// Span of discovered fan IDs, so later fans are visited even when an earlier
/// fan's keys are unavailable.
pub fn fallback_count(mut key_exists: impl FnMut(&str) -> bool) -> usize {
    let mut count = 0;
    for id in 0..MAXIMUM_FAN_COUNT {
        if ["Ac", "Mn", "Mx"]
            .iter()
            .any(|s| key_exists(&format!("F{id}{s}")))
        {
            count = id + 1;
        }
    }
    count
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validates_direct_count() {
        assert_eq!(validated_count(Some(2.0)), Some(2));
        assert_eq!(validated_count(Some(0.0)), None);
        assert_eq!(validated_count(Some(1.5)), None);
        assert_eq!(validated_count(Some(11.0)), None);
        assert_eq!(validated_count(Some(f64::NAN)), None);
        assert_eq!(validated_count(None), None);
    }

    #[test]
    fn fallback_spans_gaps() {
        assert_eq!(fallback_count(|k| k == "F2Mx"), 3);
        assert_eq!(fallback_count(|_| false), 0);
        assert!(supports(9) && !supports(10) && !supports(-1));
    }
}
