//! Background loop: samples the hardware, keeps trends, evaluates alerts and
//! drives the fan controller. The UI only reads and edits [`Shared`].
use crate::helper_client::HelperClient;
use crate::settings::{self, Settings};
use core_monitor_core::alerts::{
    self, AlertActiveState, AlertSeverity, AlertStore, EvaluationInput, HelperConnectionState,
    NotificationDelivery,
};
use core_monitor_core::fan::{self, CustomFanPreset, FanControlMode, FanInputs, SmartSettings};
use core_monitor_core::helper_protocol::{Request, RENEW_INTERVAL_SECONDS};
use core_monitor_core::snapshot::SystemSnapshot;
use core_monitor_core::trend::TrendSeries;
use core_monitor_sys::Sampler;
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

pub fn now() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0.0, |d| d.as_secs_f64())
}

#[derive(Default)]
pub struct Trends {
    pub cpu_usage: TrendSeries,
    pub cpu_temperature: TrendSeries,
    pub gpu_temperature: TrendSeries,
    pub memory: TrendSeries,
    pub download: TrendSeries,
    pub upload: TrendSeries,
    pub power: TrendSeries,
}

pub struct Shared {
    pub snapshot: SystemSnapshot,
    pub trends: Trends,
    pub settings: Settings,
    pub alerts: AlertStore,
    pub active_alerts: Vec<AlertActiveState>,
    pub unavailable_alerts: Vec<(alerts::AlertRuleKind, String)>,
    pub preset: Option<CustomFanPreset>,
    pub preset_error: Option<String>,
    pub fan_status: String,
    pub helper_state: HelperConnectionState,
    pub helper_message: Option<String>,
    pub settings_dirty: bool,
    pub alerts_dirty: bool,
    pub quit: bool,
}

pub type SharedState = Arc<Mutex<Shared>>;

pub fn start(on_sample: impl Fn() + Send + 'static) -> SharedState {
    let (preset, preset_error) = match settings::load_preset() {
        Ok(p) => (p, None),
        Err(e) => (None, Some(e)),
    };
    let shared = Arc::new(Mutex::new(Shared {
        snapshot: SystemSnapshot::default(),
        trends: Trends::default(),
        settings: settings::load_settings(),
        alerts: settings::load_alerts(),
        active_alerts: Vec::new(),
        unavailable_alerts: Vec::new(),
        preset,
        preset_error,
        fan_status: "Idle".into(),
        helper_state: HelperConnectionState::Unknown,
        helper_message: None,
        settings_dirty: false,
        alerts_dirty: false,
        quit: false,
    }));
    let state = shared.clone();
    std::thread::Builder::new()
        .name("core-monitor-engine".into())
        .spawn(move || run(state, on_sample))
        .expect("engine thread starts");
    shared
}

fn run(shared: SharedState, on_sample: impl Fn()) {
    let mut sampler = Sampler::new();
    let mut fans = FanController::default();
    loop {
        let t = now();
        let snapshot = sampler.sample(t);
        let interval;
        {
            let mut s = shared.lock().unwrap();
            if s.quit {
                fans.restore_automatic(&snapshot);
                return;
            }
            record_trends(&mut s.trends, &snapshot, t);
            let settings = s.settings.clone();
            let preset = s.preset.clone();
            s.fan_status = fans.tick(&settings, preset.as_ref(), &snapshot, t);
            s.helper_state = fans.helper.state;
            s.helper_message = fans.helper.last_error.clone();
            evaluate_alerts(&mut s, &snapshot, t);
            s.snapshot = snapshot;
            if std::mem::take(&mut s.settings_dirty) {
                settings::save_settings(&s.settings);
            }
            if std::mem::take(&mut s.alerts_dirty) {
                settings::save_alerts(&s.alerts);
            }
            interval = s.settings.refresh_interval_seconds;
        }
        on_sample();
        std::thread::sleep(Duration::from_secs_f64(interval));
    }
}

fn record_trends(trends: &mut Trends, s: &SystemSnapshot, t: f64) {
    trends.cpu_usage.append(Some(s.cpu_usage_percent), t);
    trends.cpu_temperature.append(s.cpu_temperature, t);
    trends.gpu_temperature.append(s.gpu_temperature, t);
    trends.memory.append(Some(s.memory_usage_percent), t);
    trends
        .download
        .append(Some(s.network.download_bytes_per_second), t);
    trends
        .upload
        .append(Some(s.network.upload_bytes_per_second), t);
    trends.power.append(s.total_system_watts, t);
}

fn evaluate_alerts(s: &mut Shared, snapshot: &SystemSnapshot, t: f64) {
    let input = EvaluationInput {
        snapshot,
        fan_mode: s.settings.fan_mode,
        helper_installed: HelperClient::is_installed(),
        helper_connection_state: s.helper_state,
        helper_status_message: s.helper_message.clone(),
        process_insights_enabled: s.settings.process_insights_enabled,
        now: t,
    };
    let delivery = NotificationDelivery {
        is_enabled: s.alerts.desktop_notifications_enabled,
        is_authorized: true,
        policy: s.alerts.notification_policy,
        muted_until: s.alerts.notifications_muted_until,
    };
    let mut active = Vec::new();
    let mut unavailable = Vec::new();
    let mut events = Vec::new();
    for config in s.alerts.rule_configs.clone() {
        let Some(index) = s.alerts.runtimes.iter().position(|r| r.kind == config.kind) else {
            continue;
        };
        let outcome = alerts::evaluate(&config, &s.alerts.runtimes[index], &input, &delivery);
        if outcome.runtime != s.alerts.runtimes[index] {
            s.alerts_dirty = true;
        }
        s.alerts.runtimes[index] = outcome.runtime;
        active.extend(outcome.active_state);
        if let Some(reason) = outcome.availability_reason {
            unavailable.push((config.kind, reason));
        }
        if let Some(event) = outcome.event {
            if outcome.should_notify {
                notify(&event.title, &event.message);
            }
            events.push(event);
        }
    }
    for event in events {
        s.alerts.record(event);
    }
    active.sort_by_key(|a| std::cmp::Reverse(a.severity));
    s.active_alerts = active;
    s.unavailable_alerts = unavailable;
}

/// Local desktop notification through Notification Center.
fn notify(title: &str, message: &str) {
    #[cfg(target_os = "macos")]
    {
        let esc = |s: &str| s.replace('\\', "\\\\").replace('"', "\\\"");
        let script = format!(
            "display notification \"{}\" with title \"Core-Monitor\" subtitle \"{}\"",
            esc(message),
            esc(title)
        );
        // Wait on a worker thread so the exited osascript is reaped.
        std::thread::spawn(move || {
            let _ = std::process::Command::new("/usr/bin/osascript")
                .arg("-e")
                .arg(script)
                .status();
        });
    }
    #[cfg(not(target_os = "macos"))]
    let _ = (title, message);
}

#[derive(Default)]
pub struct FanController {
    pub helper: HelperClient,
    last_applied: i64,
    last_offsets: Vec<i64>,
    last_control: Option<f64>,
    last_renew: f64,
    holds_fans: bool,
}

impl FanController {
    fn inputs(snapshot: &SystemSnapshot) -> FanInputs {
        FanInputs {
            cpu_temperature: snapshot.cpu_safety_temperature(),
            gpu_temperature: snapshot.gpu_safety_temperature(),
            system_watts: snapshot.total_system_watts,
            fan_min_speeds: snapshot.fan_min_speeds.clone(),
            fan_max_speeds: snapshot.fan_max_speeds.clone(),
        }
    }

    fn apply(&mut self, requested: &[i64], snapshot: &SystemSnapshot) -> Result<(), String> {
        if snapshot.number_of_fans == 0 {
            return Err("No controllable fans were detected.".into());
        }
        let speeds =
            fan::per_fan_speeds(requested, snapshot.number_of_fans, &Self::inputs(snapshot));
        for (fan, rpm) in speeds.iter().enumerate() {
            let response = self.helper.request(&Request::SetManual {
                fan: fan as i64,
                rpm: *rpm,
            })?;
            if !response.ok {
                return Err(response
                    .error
                    .unwrap_or_else(|| "Failed to apply fan speed".into()));
            }
        }
        self.holds_fans = true;
        Ok(())
    }

    pub fn restore_automatic(&mut self, snapshot: &SystemSnapshot) {
        if self.holds_fans || self.last_applied > 0 {
            for fan in 0..snapshot.number_of_fans {
                let _ = self.helper.request(&Request::SetAuto { fan: fan as i64 });
            }
        }
        self.holds_fans = false;
        self.last_applied = 0;
        self.last_offsets.clear();
        self.helper.disconnect();
    }

    fn control_interval(settings: &Settings, preset: Option<&CustomFanPreset>) -> f64 {
        match (settings.fan_mode, preset) {
            (FanControlMode::Custom, Some(p)) => p.resolved_update_interval(),
            _ => 2.0,
        }
    }

    pub fn tick(
        &mut self,
        settings: &Settings,
        preset: Option<&CustomFanPreset>,
        snapshot: &SystemSnapshot,
        t: f64,
    ) -> String {
        let mode = settings.fan_mode.canonical();
        if mode == FanControlMode::Automatic {
            self.restore_automatic(snapshot);
            return "System automatic: macOS controls the fans".into();
        }
        if self.holds_fans && t - self.last_renew >= RENEW_INTERVAL_SECONDS {
            self.last_renew = t;
            if self.helper.request(&Request::Renew).map(|r| r.value) != Ok(Some(1.0)) {
                // Lease expired or the helper restarted: re-apply on this tick.
                self.last_applied = 0;
                self.holds_fans = false;
            }
        }
        if self
            .last_control
            .is_some_and(|l| t - l < Self::control_interval(settings, preset))
            && self.last_applied != 0
        {
            return String::new();
        }
        self.last_control = Some(t);
        let inputs = Self::inputs(snapshot);
        let (target, requested, label): (i64, Vec<i64>, String) = match mode {
            FanControlMode::Manual => (
                settings.manual_speed,
                vec![settings.manual_speed],
                "Manual".into(),
            ),
            FanControlMode::Balanced | FanControlMode::Performance | FanControlMode::Max => {
                let target = fan::fixed_percent_target(&inputs, mode.fixed_percent().unwrap());
                (target, vec![target], mode.title().to_string())
            }
            FanControlMode::Smart => {
                let smart = SmartSettings {
                    aggressiveness: settings.auto_aggressiveness,
                    max_speed: settings.auto_max_speed,
                };
                let Some(target) = fan::smart_target(&inputs, smart) else {
                    return "Smart: waiting for live temperature data".into();
                };
                (target, vec![target], "Smart".into())
            }
            FanControlMode::Custom => {
                let Some(preset) = preset else {
                    return "Custom preset unavailable: no valid preset has been saved yet.".into();
                };
                let Some(t) =
                    fan::custom_target(preset, &inputs, self.last_applied, snapshot.number_of_fans)
                else {
                    return "Custom preset waiting for live temperature data".into();
                };
                let label = format!(
                    "Custom: {} {:.0}°C",
                    t.sensor_label, t.effective_temperature
                );
                (t.smoothed_target, t.per_fan, label)
            }
            _ => unreachable!(),
        };
        // Per-fan offsets can change (a saved preset) while the base target holds steady.
        let offsets: Vec<i64> = requested.iter().map(|r| r - target).collect();
        if fan::should_apply(target, self.last_applied) || offsets != self.last_offsets {
            if let Err(e) = self.apply(&requested, snapshot) {
                return e;
            }
            self.last_applied = target;
            self.last_offsets = offsets;
            self.last_renew = t;
        }
        format!("{label} → {target} RPM")
    }
}

#[cfg_attr(not(target_os = "macos"), allow(dead_code))]
pub fn highest_severity(active: &[AlertActiveState]) -> AlertSeverity {
    active.iter().map(|a| a.severity).max().unwrap_or_default()
}
