//! Fan modes, custom curve presets and the per-tick target calculations.
use serde::{Deserialize, Serialize};

pub const MIN_SPEED: i64 = 1_000;
pub const MAX_SPEED: i64 = 6_500;
/// Writes smaller than this are skipped to avoid hammering the SMC.
pub const APPLY_THRESHOLD_RPM: i64 = 50;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum FanControlMode {
    Smart,
    Silent,
    Balanced,
    Performance,
    Max,
    Manual,
    Custom,
    #[default]
    Automatic,
}

impl FanControlMode {
    pub const SELECTABLE: [FanControlMode; 7] = [
        Self::Automatic,
        Self::Smart,
        Self::Balanced,
        Self::Performance,
        Self::Max,
        Self::Manual,
        Self::Custom,
    ];

    /// `silent` is a legacy alias of system automatic.
    pub fn canonical(self) -> Self {
        if self == Self::Silent { Self::Automatic } else { self }
    }

    pub fn title(self) -> &'static str {
        match self {
            Self::Smart => "SMART",
            Self::Silent | Self::Automatic => "SYSTEM",
            Self::Balanced => "BALANCED",
            Self::Performance => "PERFORMANCE",
            Self::Max => "MAX",
            Self::Manual => "MANUAL",
            Self::Custom => "CUSTOM",
        }
    }

    pub fn short_title(self) -> &'static str {
        match self {
            Self::Balanced => "BAL",
            Self::Performance => "PERF",
            Self::Custom => "CODE",
            other => other.title(),
        }
    }

    pub fn summary(self) -> &'static str {
        match self.canonical() {
            Self::Smart => "Blends the hottest CPU or GPU reading with system watt draw and keeps adjusting while Core-Monitor runs.",
            Self::Balanced => "Holds fans near 60% of their maximum for steady cooling.",
            Self::Performance => "Holds fans near 85% of their maximum for sustained heavy loads.",
            Self::Max => "Runs fans at their reported maximum.",
            Self::Manual => "Holds one fixed RPM you choose.",
            Self::Custom => "Follows your saved JSON curve preset.",
            _ => "macOS controls the fans. Core-Monitor only reads them.",
        }
    }

    pub fn requires_privileged_helper(self) -> bool {
        self.canonical() != Self::Automatic
    }

    pub fn fixed_percent(self) -> Option<f64> {
        match self {
            Self::Balanced => Some(0.60),
            Self::Performance => Some(0.85),
            Self::Max => Some(1.0),
            _ => None,
        }
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PresetSensor {
    Cpu,
    Gpu,
    #[default]
    Max,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CurvePoint {
    pub temperature_c: f64,
    pub speed_percent: f64,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct PowerBoost {
    pub enabled: bool,
    pub watts_at_max_boost: f64,
    pub max_added_temperature_c: f64,
}

impl Default for PowerBoost {
    fn default() -> Self {
        Self { enabled: true, watts_at_max_boost: 40.0, max_added_temperature_c: 8.0 }
    }
}

/// JSON-compatible with the Swift app's `custom-fan-preset.json`.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CustomFanPreset {
    pub name: String,
    pub version: i64,
    pub sensor: PresetSensor,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub update_interval_seconds: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub smoothing_step_rpm: Option<i64>,
    #[serde(rename = "minimumRPM", skip_serializing_if = "Option::is_none")]
    pub minimum_rpm: Option<i64>,
    #[serde(rename = "maximumRPM", skip_serializing_if = "Option::is_none")]
    pub maximum_rpm: Option<i64>,
    #[serde(rename = "perFanRPMOffset", skip_serializing_if = "Option::is_none")]
    pub per_fan_rpm_offset: Option<Vec<i64>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub power_boost: Option<PowerBoost>,
    pub points: Vec<CurvePoint>,
}

impl CustomFanPreset {
    pub fn starter() -> Self {
        let p = |t, s| CurvePoint { temperature_c: t, speed_percent: s };
        Self {
            name: "Quiet ramp with thermal boost".into(),
            version: 1,
            sensor: PresetSensor::Max,
            update_interval_seconds: Some(2.0),
            smoothing_step_rpm: Some(100),
            minimum_rpm: Some(1400),
            maximum_rpm: Some(6200),
            per_fan_rpm_offset: Some(vec![0, 0]),
            power_boost: Some(PowerBoost { enabled: true, watts_at_max_boost: 42.0, max_added_temperature_c: 8.0 }),
            points: vec![p(38.0, 24.0), p(50.0, 32.0), p(65.0, 50.0), p(78.0, 72.0), p(88.0, 100.0)],
        }
    }

    pub fn from_json(source: &str) -> Result<Self, String> {
        serde_json::from_str(source).map_err(|e| format!("Invalid preset JSON: {e}"))
    }

    pub fn to_pretty_json(&self) -> String {
        serde_json::to_string_pretty(self).expect("preset serializes")
    }

    pub fn resolved_update_interval(&self) -> f64 {
        self.update_interval_seconds.unwrap_or(2.0).clamp(0.5, 10.0)
    }

    pub fn resolved_smoothing_step_rpm(&self) -> i64 {
        self.smoothing_step_rpm.unwrap_or(75).clamp(0, 2000)
    }

    pub fn resolved_per_fan_offsets(&self) -> Vec<i64> {
        self.per_fan_rpm_offset.iter().flatten().map(|o| (*o).clamp(-3000, 3000)).collect()
    }

    pub fn validation_errors(&self, global_min_rpm: i64, global_max_rpm: i64) -> Vec<String> {
        let mut errors = Vec::new();
        if self.name.trim().is_empty() {
            errors.push("Preset name cannot be empty.".into());
        }
        if self.version < 1 {
            errors.push("version must be 1 or greater.".into());
        }
        if self.points.len() < 2 {
            errors.push("At least two curve points are required.".into());
        }
        let mut previous = f64::NEG_INFINITY;
        for (i, point) in self.points.iter().enumerate() {
            if !(0.0..=120.0).contains(&point.temperature_c) {
                errors.push(format!("points[{i}].temperatureC must be between 0 and 120."));
            }
            if !(0.0..=100.0).contains(&point.speed_percent) {
                errors.push(format!("points[{i}].speedPercent must be between 0 and 100."));
            }
            if point.temperature_c <= previous {
                errors.push("Curve temperatures must be strictly increasing.".into());
                break;
            }
            previous = point.temperature_c;
        }
        if let Some(min) = self.minimum_rpm.filter(|m| *m < global_min_rpm) {
            let _ = min;
            errors.push(format!("minimumRPM cannot be below the app safety floor of {global_min_rpm} RPM."));
        }
        if self.maximum_rpm.is_some_and(|m| m > global_max_rpm) {
            errors.push(format!("maximumRPM cannot exceed the app safety ceiling of {global_max_rpm} RPM."));
        }
        if let (Some(min), Some(max)) = (self.minimum_rpm, self.maximum_rpm) {
            if min > max {
                errors.push("minimumRPM cannot be greater than maximumRPM.".into());
            }
        }
        if let Some(b) = &self.power_boost {
            if b.watts_at_max_boost <= 0.0 {
                errors.push("powerBoost.wattsAtMaxBoost must be greater than 0.".into());
            }
            if !(0.0..=30.0).contains(&b.max_added_temperature_c) {
                errors.push("powerBoost.maxAddedTemperatureC must be between 0 and 30.".into());
            }
        }
        if self.update_interval_seconds.is_some_and(|u| !(0.5..=10.0).contains(&u)) {
            errors.push("updateIntervalSeconds must be between 0.5 and 10 seconds.".into());
        }
        if self.smoothing_step_rpm.is_some_and(|s| !(0..=2000).contains(&s)) {
            errors.push("smoothingStepRPM must be between 0 and 2000 RPM.".into());
        }
        for (i, offset) in self.per_fan_rpm_offset.iter().flatten().enumerate() {
            if offset.abs() > 3000 {
                errors.push(format!("perFanRPMOffset[{i}] must stay between -3000 and 3000 RPM."));
            }
        }
        errors
    }

    pub fn interpolated_speed_percent(&self, t: f64) -> f64 {
        let (Some(first), Some(last)) = (self.points.first(), self.points.last()) else { return 0.0 };
        if t <= first.temperature_c {
            return first.speed_percent;
        }
        if t >= last.temperature_c {
            return last.speed_percent;
        }
        for w in self.points.windows(2) {
            let (l, r) = (w[0], w[1]);
            if t < l.temperature_c || t > r.temperature_c {
                continue;
            }
            let span = r.temperature_c - l.temperature_c;
            if span <= 0.0 {
                return r.speed_percent;
            }
            return l.speed_percent + (r.speed_percent - l.speed_percent) * (t - l.temperature_c) / span;
        }
        last.speed_percent
    }

    pub fn power_boost_c(&self, system_watts: Option<f64>) -> f64 {
        match self.power_boost {
            Some(b) if b.enabled => {
                let ratio = (system_watts.unwrap_or(0.0).abs() / b.watts_at_max_boost.max(0.1)).clamp(0.0, 1.0);
                ratio * b.max_added_temperature_c
            }
            _ => 0.0,
        }
    }
}

/// Live inputs a managed profile needs each tick.
#[derive(Clone, Debug, Default)]
pub struct FanInputs {
    pub cpu_temperature: Option<f64>,
    pub gpu_temperature: Option<f64>,
    pub system_watts: Option<f64>,
    pub fan_min_speeds: Vec<i64>,
    pub fan_max_speeds: Vec<i64>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct SmartSettings {
    pub aggressiveness: f64,
    pub max_speed: i64,
}

impl Default for SmartSettings {
    fn default() -> Self {
        Self { aggressiveness: 1.5, max_speed: MAX_SPEED }
    }
}

pub fn should_apply(target: i64, last_applied: i64) -> bool {
    last_applied == 0 || (target - last_applied).abs() >= APPLY_THRESHOLD_RPM
}

/// Smart mode: hottest sensor plus up to 8°C of watt boost mapped from
/// 35–92°C onto `[MIN_SPEED, max_speed]`, blended by aggressiveness 0–3.
pub fn smart_target(inputs: &FanInputs, settings: SmartSettings) -> Option<i64> {
    let max_temp = inputs.cpu_temperature.unwrap_or(0.0).max(inputs.gpu_temperature.unwrap_or(0.0));
    if max_temp <= 0.0 {
        return None;
    }
    let (min, max) = (MIN_SPEED as f64, settings.max_speed.clamp(MIN_SPEED, MAX_SPEED) as f64);
    let watt_boost = (inputs.system_watts.unwrap_or(0.0).abs() / 40.0).min(1.0) * 8.0;
    let effective = (max_temp + watt_boost).min(105.0);
    let ratio = ((effective - 35.0) / (92.0 - 35.0)).clamp(0.0, 1.0);
    let temp_based = min + (max - min) * ratio;
    let response = settings.aggressiveness.clamp(0.0, 3.0);
    let target = if response <= 1.5 {
        let blend = response / 1.5;
        min * (1.0 - blend) + temp_based * blend
    } else {
        let blend = (response - 1.5) / 1.5;
        temp_based * (1.0 - blend) + max * blend
    };
    Some(target.clamp(min, max) as i64)
}

pub fn fixed_percent_target(inputs: &FanInputs, percent: f64) -> i64 {
    let first_max = inputs.fan_max_speeds.first().copied().unwrap_or(MAX_SPEED);
    (first_max as f64 * percent).round() as i64
}

#[derive(Clone, Debug, PartialEq)]
pub struct CustomTarget {
    pub sensor_label: &'static str,
    pub effective_temperature: f64,
    pub smoothed_target: i64,
    pub per_fan: Vec<i64>,
}

pub fn custom_target(preset: &CustomFanPreset, inputs: &FanInputs, last_applied: i64, fan_count: usize) -> Option<CustomTarget> {
    let (cpu, gpu) = (inputs.cpu_temperature.unwrap_or(0.0), inputs.gpu_temperature.unwrap_or(0.0));
    let (base, label) = match preset.sensor {
        PresetSensor::Cpu => (cpu, "CPU"),
        PresetSensor::Gpu => (gpu, "GPU"),
        PresetSensor::Max => (cpu.max(gpu), if gpu > cpu { "GPU" } else { "CPU" }),
    };
    if base <= 0.0 {
        return None;
    }
    let effective = (base + preset.power_boost_c(inputs.system_watts)).min(120.0);
    let percent = preset.interpolated_speed_percent(effective).clamp(0.0, 100.0);
    let fallback_min = inputs.fan_min_speeds.first().copied().unwrap_or(MIN_SPEED);
    let fallback_max = inputs.fan_max_speeds.first().copied().unwrap_or(MAX_SPEED);
    let preset_min = preset.minimum_rpm.unwrap_or(fallback_min).max(MIN_SPEED);
    let preset_max = preset.maximum_rpm.unwrap_or(fallback_max).min(MAX_SPEED);
    let (lo, hi) = (preset_min.min(preset_max), preset_min.max(preset_max));
    let base_rpm = (lo as f64 + (hi - lo) as f64 * percent / 100.0).round() as i64;
    let step = preset.resolved_smoothing_step_rpm();
    let smoothed = if step > 0 && last_applied > 0 && (base_rpm - last_applied).abs() > step {
        last_applied + step * (base_rpm - last_applied).signum()
    } else {
        base_rpm
    };
    let offsets = preset.resolved_per_fan_offsets();
    let per_fan = (0..fan_count.max(1)).map(|i| smoothed + offsets.get(i).copied().unwrap_or(0)).collect();
    Some(CustomTarget { sensor_label: label, effective_temperature: effective, smoothed_target: smoothed, per_fan })
}

/// Expands requested speeds to every fan and clamps each to its reported range.
pub fn per_fan_speeds(requested: &[i64], fan_count: usize, inputs: &FanInputs) -> Vec<i64> {
    (0..fan_count)
        .map(|i| {
            let min = inputs.fan_min_speeds.get(i).copied().unwrap_or(MIN_SPEED);
            let max = inputs.fan_max_speeds.get(i).copied().unwrap_or(MAX_SPEED);
            let r = requested.get(i).or(requested.last()).copied().unwrap_or(MIN_SPEED);
            r.min(max).max(min)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn inputs(cpu: f64, gpu: f64, watts: f64) -> FanInputs {
        FanInputs {
            cpu_temperature: Some(cpu),
            gpu_temperature: Some(gpu),
            system_watts: Some(watts),
            fan_min_speeds: vec![1200, 1200],
            fan_max_speeds: vec![6000, 5800],
        }
    }

    #[test]
    fn starter_preset_is_valid_and_round_trips() {
        let p = CustomFanPreset::starter();
        assert!(p.validation_errors(MIN_SPEED, MAX_SPEED).is_empty());
        let json = p.to_pretty_json();
        assert!(json.contains("\"minimumRPM\": 1400") && json.contains("\"temperatureC\""));
        assert_eq!(CustomFanPreset::from_json(&json).unwrap(), p);
    }

    #[test]
    fn decodes_swift_preset_with_ids_and_missing_optionals() {
        let src = r#"{"name":"x","version":1,"sensor":"cpu","points":[
            {"id":"9A1F0D52-1E0B-4C7F-A9E7-6D9C9C0B1F11","temperatureC":40,"speedPercent":10},
            {"temperatureC":80,"speedPercent":90}]}"#;
        let p = CustomFanPreset::from_json(src).unwrap();
        assert_eq!(p.sensor, PresetSensor::Cpu);
        assert_eq!(p.resolved_smoothing_step_rpm(), 75);
        assert_eq!(p.resolved_update_interval(), 2.0);
    }

    #[test]
    fn validation_reports_each_problem() {
        let mut p = CustomFanPreset::starter();
        p.name = " ".into();
        p.minimum_rpm = Some(500);
        p.maximum_rpm = Some(7000);
        p.points[2].temperature_c = 40.0;
        p.per_fan_rpm_offset = Some(vec![0, 4000]);
        let errors = p.validation_errors(MIN_SPEED, MAX_SPEED);
        assert!(errors.iter().any(|e| e.contains("name")));
        assert!(errors.iter().any(|e| e.contains("safety floor")));
        assert!(errors.iter().any(|e| e.contains("safety ceiling")));
        assert!(errors.iter().any(|e| e.contains("strictly increasing")));
        assert!(errors.iter().any(|e| e.contains("perFanRPMOffset[1]")));
    }

    #[test]
    fn interpolates_and_clamps_curve() {
        let p = CustomFanPreset::starter();
        assert_eq!(p.interpolated_speed_percent(20.0), 24.0);
        assert_eq!(p.interpolated_speed_percent(95.0), 100.0);
        assert!((p.interpolated_speed_percent(57.5) - 41.0).abs() < 1e-9);
    }

    #[test]
    fn smart_mode_blends_aggressiveness() {
        assert_eq!(smart_target(&inputs(0.0, 0.0, 0.0), SmartSettings::default()), None);
        let cool = SmartSettings { aggressiveness: 0.0, max_speed: 6500 };
        assert_eq!(smart_target(&inputs(90.0, 50.0, 100.0), cool), Some(1000));
        let max = SmartSettings { aggressiveness: 3.0, max_speed: 6500 };
        assert_eq!(smart_target(&inputs(40.0, 0.0, 0.0), max), Some(6500));
        let mid = SmartSettings::default();
        // 35°C + 0 boost -> ratio 0 -> min speed
        assert_eq!(smart_target(&inputs(35.0, 0.0, 0.0), mid), Some(1000));
        // 84°C + 8°C boost = 92°C -> ratio 1 -> max speed
        assert_eq!(smart_target(&inputs(84.0, 0.0, 40.0), mid), Some(6500));
    }

    #[test]
    fn custom_mode_smooths_and_offsets() {
        let mut p = CustomFanPreset::starter();
        p.per_fan_rpm_offset = Some(vec![0, 200]);
        let t = custom_target(&p, &inputs(88.0, 60.0, 0.0), 0, 2).unwrap();
        assert_eq!((t.sensor_label, t.smoothed_target), ("CPU", 6200));
        assert_eq!(t.per_fan, vec![6200, 6400]);
        let t = custom_target(&p, &inputs(88.0, 60.0, 0.0), 3000, 2).unwrap();
        assert_eq!(t.smoothed_target, 3100);
        assert!(custom_target(&p, &inputs(0.0, 0.0, 0.0), 0, 2).is_none());
    }

    #[test]
    fn fixed_profiles_and_clamping() {
        let i = inputs(50.0, 50.0, 0.0);
        assert_eq!(fixed_percent_target(&i, FanControlMode::Balanced.fixed_percent().unwrap()), 3600);
        assert_eq!(per_fan_speeds(&[7000], 2, &i), vec![6000, 5800]);
        assert_eq!(per_fan_speeds(&[100, 3000], 2, &i), vec![1200, 3000]);
        assert!(should_apply(3000, 0) && !should_apply(3049, 3000) && should_apply(3050, 3000));
        assert!(!FanControlMode::Silent.requires_privileged_helper());
        assert!(FanControlMode::Manual.requires_privileged_helper());
    }
}
