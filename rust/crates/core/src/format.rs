//! Display formatting shared by the menu bar and dashboard.

fn formatted(bytes_per_second: f64, units: &[&str]) -> String {
    let normalized = bytes_per_second.abs().max(0.0);
    if !normalized.is_finite() {
        return format!("0 {}", units[0]);
    }
    let (mut value, mut unit) = (normalized, 0);
    while value >= 1_000.0 && unit < units.len() - 1 {
        value /= 1_000.0;
        unit += 1;
    }
    let decimals = if unit > 0 && value < 10.0 { 1 } else { 0 };
    format!("{value:.decimals$} {}", units[unit])
}

pub fn compact_rate(bytes_per_second: f64) -> String {
    formatted(bytes_per_second, &["B/s", "KB/s", "MB/s", "GB/s", "TB/s"])
}

pub fn abbreviated_rate(bytes_per_second: f64) -> String {
    formatted(bytes_per_second, &["B", "K", "M", "G", "T"])
}

pub fn bytes(value: u64) -> String {
    formatted(value as f64, &["B", "KB", "MB", "GB", "TB"]).replace(".0 ", " ")
}

pub fn time_remaining_minutes(
    is_charging: bool,
    is_plugged_in: bool,
    time_to_empty: Option<i64>,
    time_to_full: Option<i64>,
) -> Option<i64> {
    if !(is_charging || !is_plugged_in) {
        return None;
    }
    let minutes = if is_charging {
        time_to_full
    } else {
        time_to_empty
    }?;
    (minutes >= 0).then_some(minutes)
}

pub fn duration(minutes: i64) -> String {
    let minutes = minutes.max(0);
    match (minutes / 60, minutes % 60) {
        (0, m) => format!("{m}m"),
        (h, 0) => format!("{h}h"),
        (h, m) => format!("{h}h {m}m"),
    }
}

pub fn runtime_description(
    is_charging: bool,
    is_plugged_in: bool,
    minutes: Option<i64>,
) -> Option<String> {
    if !(is_charging || !is_plugged_in) {
        return None;
    }
    let minutes = minutes.filter(|m| *m >= 0)?;
    Some(match (minutes, is_charging) {
        (0, true) => "Finishing soon".into(),
        (0, false) => "Less than 1m remaining".into(),
        (m, true) => format!("{} until full", duration(m)),
        (m, false) => format!("{} remaining", duration(m)),
    })
}

pub fn power_state(is_charging: bool, is_plugged_in: bool) -> &'static str {
    match (is_charging, is_plugged_in) {
        (true, _) => "Charging",
        (false, true) => "AC Power",
        _ => "Battery Power",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rates() {
        assert_eq!(compact_rate(0.0), "0 B/s");
        assert_eq!(compact_rate(999.0), "999 B/s");
        assert_eq!(compact_rate(1_500.0), "1.5 KB/s");
        assert_eq!(compact_rate(25_000_000.0), "25 MB/s");
        assert_eq!(abbreviated_rate(-2_000.0), "2.0 K");
        assert_eq!(compact_rate(f64::INFINITY), "0 B/s");
    }

    #[test]
    fn battery_runtime() {
        assert_eq!(
            time_remaining_minutes(false, true, Some(30), Some(40)),
            None
        );
        assert_eq!(
            time_remaining_minutes(true, true, Some(30), Some(40)),
            Some(40)
        );
        assert_eq!(time_remaining_minutes(false, false, Some(-1), None), None);
        assert_eq!(
            runtime_description(false, false, Some(95)).as_deref(),
            Some("1h 35m remaining")
        );
        assert_eq!(
            runtime_description(true, true, Some(0)).as_deref(),
            Some("Finishing soon")
        );
        assert_eq!(power_state(false, true), "AC Power");
    }
}
