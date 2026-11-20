//! Settings, alert state and the custom preset, stored as JSON under
//! `~/Library/Application Support/Core-Monitor`.
use core_monitor_core::alerts::AlertStore;
use core_monitor_core::fan::{CustomFanPreset, FanControlMode, MAX_SPEED, MIN_SPEED};
use serde::{de::DeserializeOwned, Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(default, rename_all = "camelCase")]
pub struct Settings {
    pub fan_mode: FanControlMode,
    pub manual_speed: i64,
    pub auto_aggressiveness: f64,
    pub auto_max_speed: i64,
    pub refresh_interval_seconds: f64,
    pub process_insights_enabled: bool,
    pub menu_bar_shows_temperature: bool,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            fan_mode: FanControlMode::Automatic,
            manual_speed: 2200,
            auto_aggressiveness: 1.5,
            auto_max_speed: MAX_SPEED,
            refresh_interval_seconds: 1.0,
            process_insights_enabled: true,
            menu_bar_shows_temperature: true,
        }
    }
}

impl Settings {
    pub fn sanitized(mut self) -> Self {
        self.manual_speed = self.manual_speed.clamp(MIN_SPEED, MAX_SPEED);
        self.auto_aggressiveness = self.auto_aggressiveness.clamp(0.0, 3.0);
        self.auto_max_speed = self.auto_max_speed.clamp(MIN_SPEED, MAX_SPEED);
        self.refresh_interval_seconds = self.refresh_interval_seconds.clamp(0.5, 10.0);
        self
    }
}

pub fn support_dir() -> PathBuf {
    let home = std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(std::env::temp_dir);
    home.join("Library/Application Support/Core-Monitor")
}

pub fn preset_path() -> PathBuf {
    support_dir().join("custom-fan-preset.json")
}

fn load<T: DeserializeOwned>(name: &str) -> Option<T> {
    serde_json::from_str(&std::fs::read_to_string(support_dir().join(name)).ok()?).ok()
}

fn save<T: Serialize>(name: &str, value: &T) {
    let dir = support_dir();
    if std::fs::create_dir_all(&dir).is_ok() {
        if let Ok(json) = serde_json::to_string_pretty(value) {
            let tmp = dir.join(format!("{name}.tmp"));
            if std::fs::write(&tmp, json).is_ok() {
                let _ = std::fs::rename(tmp, dir.join(name));
            }
        }
    }
}

pub fn load_settings() -> Settings {
    load::<Settings>("settings.json")
        .unwrap_or_default()
        .sanitized()
}

pub fn save_settings(settings: &Settings) {
    save("settings.json", settings);
}

pub fn load_alerts() -> AlertStore {
    load("alerts.json").unwrap_or_default()
}

pub fn save_alerts(store: &AlertStore) {
    save("alerts.json", store);
}

/// Returns the saved preset, or the validation error that kept it from loading.
pub fn load_preset() -> Result<Option<CustomFanPreset>, String> {
    let Ok(source) = std::fs::read_to_string(preset_path()) else {
        return Ok(None);
    };
    let preset = CustomFanPreset::from_json(&source)?;
    let errors = preset.validation_errors(MIN_SPEED, MAX_SPEED);
    if errors.is_empty() {
        Ok(Some(preset))
    } else {
        Err(errors.join(" "))
    }
}

pub fn save_preset_source(source: &str) -> Result<CustomFanPreset, Vec<String>> {
    let preset = CustomFanPreset::from_json(source).map_err(|e| vec![e])?;
    let errors = preset.validation_errors(MIN_SPEED, MAX_SPEED);
    if !errors.is_empty() {
        return Err(errors);
    }
    save("custom-fan-preset.json", &preset);
    Ok(preset)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn settings_sanitize_and_tolerate_missing_fields() {
        let s: Settings =
            serde_json::from_str(r#"{"fanMode":"manual","manualSpeed":99999}"#).unwrap();
        let s = s.sanitized();
        assert_eq!(
            (s.fan_mode, s.manual_speed, s.auto_aggressiveness),
            (FanControlMode::Manual, MAX_SPEED, 1.5)
        );
    }
}
