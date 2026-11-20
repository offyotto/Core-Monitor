//! Alert rules, presets and the debounce/hysteresis/cooldown evaluator.
use crate::fan::FanControlMode;
use crate::snapshot::{SystemSnapshot, TopProcessSnapshot};
use crate::Timestamp;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum AlertCategory {
    Thermal,
    Performance,
    FanSafety,
    Battery,
    Services,
}

impl AlertCategory {
    pub fn title(self) -> &'static str {
        ["Thermal", "Performance", "Fan Safety", "Battery", "Services"][self as usize]
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub enum AlertSeverity {
    #[default]
    None = 0,
    Info = 1,
    Warning = 2,
    Critical = 3,
}

impl AlertSeverity {
    pub fn title(self) -> &'static str {
        ["Stable", "Info", "Warning", "Critical"][self as usize]
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum AlertRuleKind {
    CpuTemperature,
    GpuTemperature,
    OverallThermalState,
    CpuUsage,
    MemoryPressure,
    SwapUsage,
    FanTooLowUnderHeat,
    BatteryTemperature,
    BatteryHealth,
    LowBatteryDischarging,
    SmcUnavailable,
    HelperUnavailable,
}

impl AlertRuleKind {
    pub const ALL: [AlertRuleKind; 12] = [
        Self::CpuTemperature,
        Self::GpuTemperature,
        Self::OverallThermalState,
        Self::CpuUsage,
        Self::MemoryPressure,
        Self::SwapUsage,
        Self::FanTooLowUnderHeat,
        Self::BatteryTemperature,
        Self::BatteryHealth,
        Self::LowBatteryDischarging,
        Self::SmcUnavailable,
        Self::HelperUnavailable,
    ];

    pub fn category(self) -> AlertCategory {
        use AlertRuleKind::*;
        match self {
            CpuTemperature | GpuTemperature | OverallThermalState => AlertCategory::Thermal,
            CpuUsage | MemoryPressure | SwapUsage => AlertCategory::Performance,
            FanTooLowUnderHeat => AlertCategory::FanSafety,
            BatteryTemperature | BatteryHealth | LowBatteryDischarging => AlertCategory::Battery,
            SmcUnavailable | HelperUnavailable => AlertCategory::Services,
        }
    }

    pub fn title(self) -> &'static str {
        [
            "CPU Temperature",
            "GPU Temperature",
            "Overall Thermal",
            "CPU Usage",
            "Memory Pressure",
            "Swap Usage",
            "Fan Stalled / Too Low",
            "Battery Temperature",
            "Battery Health",
            "Low Battery",
            "SMC Access",
            "Helper Availability",
        ][self as usize]
    }

    pub fn subtitle(self) -> &'static str {
        [
            "Protect against sustained CPU heat.",
            "Protect against sustained GPU heat.",
            "Uses macOS thermal pressure, not a guessed sensor.",
            "Flags sustained CPU saturation with top-app context.",
            "Flags yellow and red memory pressure.",
            "Tracks swap growth that typically hurts responsiveness.",
            "Detects stalled fans or fan RPM that stays too low while hot.",
            "Warn when pack temperature rises above safe comfort.",
            "Warn when reported health falls below target.",
            "Warn on low charge while unplugged.",
            "Warn when AppleSMC cannot be opened.",
            "Warn when privileged fan control cannot be used.",
        ][self as usize]
    }

    pub fn unit_label(self) -> Option<&'static str> {
        use AlertRuleKind::*;
        match self {
            CpuTemperature | GpuTemperature | BatteryTemperature => Some("°C"),
            CpuUsage | BatteryHealth | LowBatteryDischarging => Some("%"),
            SwapUsage => Some("GB"),
            _ => None,
        }
    }

    pub fn supports_threshold_editing(self) -> bool {
        use AlertRuleKind::*;
        matches!(
            self,
            CpuTemperature | GpuTemperature | CpuUsage | SwapUsage | BatteryTemperature | BatteryHealth | LowBatteryDischarging
        )
    }

    pub fn supports_desktop_notifications(self) -> bool {
        self != Self::BatteryHealth
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct AlertThreshold {
    pub warning: Option<f64>,
    pub critical: Option<f64>,
    pub hysteresis: f64,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AlertRuleConfig {
    pub kind: AlertRuleKind,
    pub is_enabled: bool,
    pub threshold: AlertThreshold,
    pub cooldown_minutes: i64,
    pub debounce_samples: i64,
    pub desktop_notifications_enabled: bool,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum AlertPreset {
    #[default]
    Default,
    Quiet,
    Performance,
    AggressiveThermalSafety,
}

impl AlertPreset {
    pub const ALL: [AlertPreset; 4] = [Self::Default, Self::Quiet, Self::Performance, Self::AggressiveThermalSafety];

    pub fn title(self) -> &'static str {
        ["Default", "Quiet", "Performance", "Aggressive Thermal Safety"][self as usize]
    }

    pub fn subtitle(self) -> &'static str {
        [
            "Balanced thresholds with critical desktop alerts.",
            "Fewer desktop notifications and longer repeat windows.",
            "Earlier CPU, memory, and swap warnings.",
            "Earlier heat and fan warnings.",
        ][self as usize]
    }

    pub fn configurations(self) -> Vec<AlertRuleConfig> {
        AlertRuleKind::ALL.iter().map(|k| self.configuration(*k)).collect()
    }

    pub fn configuration(self, kind: AlertRuleKind) -> AlertRuleConfig {
        if matches!(kind, AlertRuleKind::SmcUnavailable | AlertRuleKind::HelperUnavailable) {
            let cooldown = match self {
                AlertPreset::Quiet => 40,
                AlertPreset::AggressiveThermalSafety => 10,
                _ => 30,
            };
            return AlertRuleConfig {
                kind,
                is_enabled: true,
                threshold: AlertThreshold::default(),
                cooldown_minutes: cooldown,
                debounce_samples: 1,
                desktop_notifications_enabled: true,
            };
        }
        let (w, c, h, cooldown, debounce, notify) = match (self, kind) {
        (AlertPreset::Default, AlertRuleKind::CpuTemperature) => (85.0, 95.0, 3.0, 20, 2, true),
        (AlertPreset::Default, AlertRuleKind::GpuTemperature) => (82.0, 92.0, 3.0, 20, 2, true),
        (AlertPreset::Default, AlertRuleKind::OverallThermalState) => (2.0, 3.0, 0.0, 15, 1, true),
        (AlertPreset::Default, AlertRuleKind::CpuUsage) => (88.0, 98.0, 8.0, 20, 3, true),
        (AlertPreset::Default, AlertRuleKind::MemoryPressure) => (1.0, 2.0, 0.0, 15, 2, true),
        (AlertPreset::Default, AlertRuleKind::SwapUsage) => (4.0, 10.0, 1.0, 20, 2, true),
        (AlertPreset::Default, AlertRuleKind::FanTooLowUnderHeat) => (85.0, 95.0, 3.0, 10, 2, true),
        (AlertPreset::Default, AlertRuleKind::BatteryTemperature) => (38.0, 45.0, 2.0, 20, 2, true),
        (AlertPreset::Default, AlertRuleKind::BatteryHealth) => (82.0, 70.0, 0.0, 1440, 1, false),
        (AlertPreset::Default, AlertRuleKind::LowBatteryDischarging) => (18.0, 10.0, 3.0, 30, 1, true),
        (AlertPreset::Quiet, AlertRuleKind::CpuTemperature) => (90.0, 100.0, 3.0, 35, 3, true),
        (AlertPreset::Quiet, AlertRuleKind::GpuTemperature) => (88.0, 98.0, 3.0, 35, 3, true),
        (AlertPreset::Quiet, AlertRuleKind::OverallThermalState) => (2.0, 3.0, 0.0, 30, 2, true),
        (AlertPreset::Quiet, AlertRuleKind::CpuUsage) => (93.0, 99.0, 8.0, 35, 4, false),
        (AlertPreset::Quiet, AlertRuleKind::MemoryPressure) => (2.0, 2.0, 0.0, 25, 2, false),
        (AlertPreset::Quiet, AlertRuleKind::SwapUsage) => (8.0, 14.0, 1.0, 35, 3, false),
        (AlertPreset::Quiet, AlertRuleKind::FanTooLowUnderHeat) => (90.0, 98.0, 3.0, 15, 3, true),
        (AlertPreset::Quiet, AlertRuleKind::BatteryTemperature) => (40.0, 46.0, 2.0, 35, 2, false),
        (AlertPreset::Quiet, AlertRuleKind::BatteryHealth) => (80.0, 68.0, 0.0, 1440, 1, false),
        (AlertPreset::Quiet, AlertRuleKind::LowBatteryDischarging) => (12.0, 7.0, 3.0, 40, 1, true),
        (AlertPreset::Performance, AlertRuleKind::CpuTemperature) => (82.0, 92.0, 3.0, 15, 2, true),
        (AlertPreset::Performance, AlertRuleKind::GpuTemperature) => (80.0, 90.0, 3.0, 15, 2, true),
        (AlertPreset::Performance, AlertRuleKind::OverallThermalState) => (1.0, 2.0, 0.0, 12, 1, true),
        (AlertPreset::Performance, AlertRuleKind::CpuUsage) => (80.0, 94.0, 7.0, 12, 2, true),
        (AlertPreset::Performance, AlertRuleKind::MemoryPressure) => (1.0, 2.0, 0.0, 12, 1, true),
        (AlertPreset::Performance, AlertRuleKind::SwapUsage) => (2.0, 6.0, 1.0, 15, 2, true),
        (AlertPreset::Performance, AlertRuleKind::FanTooLowUnderHeat) => (82.0, 92.0, 3.0, 8, 2, true),
        (AlertPreset::Performance, AlertRuleKind::BatteryTemperature) => (37.0, 43.0, 2.0, 18, 2, true),
        (AlertPreset::Performance, AlertRuleKind::BatteryHealth) => (82.0, 70.0, 0.0, 1440, 1, false),
        (AlertPreset::Performance, AlertRuleKind::LowBatteryDischarging) => (20.0, 12.0, 3.0, 30, 1, true),
        (AlertPreset::AggressiveThermalSafety, AlertRuleKind::CpuTemperature) => (78.0, 88.0, 3.0, 8, 1, true),
        (AlertPreset::AggressiveThermalSafety, AlertRuleKind::GpuTemperature) => (76.0, 86.0, 3.0, 8, 1, true),
        (AlertPreset::AggressiveThermalSafety, AlertRuleKind::OverallThermalState) => (1.0, 2.0, 0.0, 8, 1, true),
        (AlertPreset::AggressiveThermalSafety, AlertRuleKind::CpuUsage) => (82.0, 95.0, 6.0, 10, 2, true),
        (AlertPreset::AggressiveThermalSafety, AlertRuleKind::MemoryPressure) => (1.0, 2.0, 0.0, 10, 1, true),
        (AlertPreset::AggressiveThermalSafety, AlertRuleKind::SwapUsage) => (3.0, 7.0, 1.0, 10, 1, true),
        (AlertPreset::AggressiveThermalSafety, AlertRuleKind::FanTooLowUnderHeat) => (78.0, 88.0, 3.0, 5, 1, true),
        (AlertPreset::AggressiveThermalSafety, AlertRuleKind::BatteryTemperature) => (36.0, 42.0, 2.0, 10, 1, true),
        (AlertPreset::AggressiveThermalSafety, AlertRuleKind::BatteryHealth) => (84.0, 72.0, 0.0, 1440, 1, false),
        (AlertPreset::AggressiveThermalSafety, AlertRuleKind::LowBatteryDischarging) => (18.0, 10.0, 3.0, 20, 1, true),
            _ => unreachable!("service rules handled above"),
        };
        AlertRuleConfig {
            kind,
            is_enabled: true,
            threshold: AlertThreshold { warning: Some(w), critical: Some(c), hysteresis: h },
            cooldown_minutes: cooldown,
            debounce_samples: debounce,
            desktop_notifications_enabled: notify,
        }
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum NotificationPolicy {
    InAppOnly,
    #[default]
    CriticalOnly,
    WarningsAndCritical,
}

impl NotificationPolicy {
    pub fn title(self) -> &'static str {
        ["In-App Only", "Critical Only", "Warnings + Critical"][self as usize]
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AlertEvent {
    pub id: Uuid,
    pub kind: AlertRuleKind,
    pub severity: AlertSeverity,
    pub title: String,
    pub message: String,
    pub context: Option<String>,
    pub timestamp: Timestamp,
    pub is_recovery: bool,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AlertRuleRuntime {
    pub kind: AlertRuleKind,
    pub active_severity: AlertSeverity,
    pub pending_severity: AlertSeverity,
    pub pending_sample_count: i64,
    pub last_event_date: Option<Timestamp>,
    pub last_notification_date: Option<Timestamp>,
    pub snoozed_until: Option<Timestamp>,
    pub dismiss_until_recovery: bool,
    pub last_metric_value: Option<f64>,
}

impl AlertRuleRuntime {
    pub fn initial(kind: AlertRuleKind) -> Self {
        Self {
            kind,
            active_severity: AlertSeverity::None,
            pending_severity: AlertSeverity::None,
            pending_sample_count: 0,
            last_event_date: None,
            last_notification_date: None,
            snoozed_until: None,
            dismiss_until_recovery: false,
            last_metric_value: None,
        }
    }

    fn reset(&self) -> Self {
        Self {
            active_severity: AlertSeverity::None,
            pending_severity: AlertSeverity::None,
            pending_sample_count: 0,
            last_metric_value: None,
            dismiss_until_recovery: false,
            ..self.clone()
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct AlertActiveState {
    pub kind: AlertRuleKind,
    pub severity: AlertSeverity,
    pub title: String,
    pub message: String,
    pub context: Option<String>,
    pub started_at: Timestamp,
    pub updated_at: Timestamp,
    pub metric_value: Option<f64>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AlertStore {
    pub selected_preset: AlertPreset,
    pub notification_policy: NotificationPolicy,
    pub desktop_notifications_enabled: bool,
    pub notifications_muted_until: Option<Timestamp>,
    pub rule_configs: Vec<AlertRuleConfig>,
    pub runtimes: Vec<AlertRuleRuntime>,
    pub history: Vec<AlertEvent>,
}

impl Default for AlertStore {
    fn default() -> Self {
        Self {
            selected_preset: AlertPreset::Default,
            notification_policy: NotificationPolicy::CriticalOnly,
            desktop_notifications_enabled: true,
            notifications_muted_until: None,
            rule_configs: AlertPreset::Default.configurations(),
            runtimes: AlertRuleKind::ALL.iter().map(|k| AlertRuleRuntime::initial(*k)).collect(),
            history: Vec::new(),
        }
    }
}

impl AlertStore {
    pub const HISTORY_LIMIT: usize = 120;

    pub fn apply_preset(&mut self, preset: AlertPreset) {
        self.selected_preset = preset;
        self.rule_configs = preset.configurations();
    }

    pub fn record(&mut self, event: AlertEvent) {
        self.history.insert(0, event);
        self.history.truncate(Self::HISTORY_LIMIT);
    }
}

/// Mirrors `SMCHelperManager.ConnectionState`.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum HelperConnectionState {
    Missing,
    #[default]
    Unknown,
    Checking,
    Reachable,
    Unreachable,
}

#[derive(Clone, Debug)]
pub struct EvaluationInput<'a> {
    pub snapshot: &'a SystemSnapshot,
    pub fan_mode: FanControlMode,
    pub helper_installed: bool,
    pub helper_connection_state: HelperConnectionState,
    pub helper_status_message: Option<String>,
    pub process_insights_enabled: bool,
    pub now: Timestamp,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Measurement {
    pub severity: AlertSeverity,
    pub metric_value: Option<f64>,
    pub title: String,
    pub message: String,
    pub context: Option<String>,
    pub unavailable_reason: Option<String>,
}

impl Measurement {
    fn new(severity: AlertSeverity, metric: Option<f64>, title: &str, message: String, context: Option<String>) -> Self {
        Self { severity, metric_value: metric, title: title.into(), message, context, unavailable_reason: None }
    }

    fn unavailable(kind: AlertRuleKind, reason: &str) -> Self {
        Self {
            severity: AlertSeverity::None,
            metric_value: None,
            title: kind.title().into(),
            message: kind.subtitle().into(),
            context: None,
            unavailable_reason: Some(reason.into()),
        }
    }

    pub fn is_available(&self) -> bool {
        self.unavailable_reason.is_none()
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct EvaluationOutcome {
    pub runtime: AlertRuleRuntime,
    pub active_state: Option<AlertActiveState>,
    pub event: Option<AlertEvent>,
    pub should_notify: bool,
    pub availability_reason: Option<String>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct NotificationDelivery {
    pub is_enabled: bool,
    pub is_authorized: bool,
    pub policy: NotificationPolicy,
    pub muted_until: Option<Timestamp>,
}

impl Default for NotificationDelivery {
    fn default() -> Self {
        Self { is_enabled: true, is_authorized: true, policy: NotificationPolicy::WarningsAndCritical, muted_until: None }
    }
}

impl NotificationDelivery {
    pub fn allows(&self, severity: AlertSeverity, now: Timestamp) -> bool {
        if !self.is_enabled || !self.is_authorized || self.muted_until.is_some_and(|m| m > now) {
            return false;
        }
        match self.policy {
            NotificationPolicy::InAppOnly => false,
            NotificationPolicy::CriticalOnly => severity == AlertSeverity::Critical,
            NotificationPolicy::WarningsAndCritical => severity >= AlertSeverity::Warning,
        }
    }
}

fn outcome(runtime: AlertRuleRuntime, active: Option<AlertActiveState>, event: Option<AlertEvent>, notify: bool) -> EvaluationOutcome {
    EvaluationOutcome { runtime, active_state: active, event, should_notify: notify, availability_reason: None }
}

fn active_state(kind: AlertRuleKind, severity: AlertSeverity, m: &Measurement, started: Timestamp, updated: Timestamp) -> AlertActiveState {
    AlertActiveState {
        kind,
        severity,
        title: m.title.clone(),
        message: m.message.clone(),
        context: m.context.clone(),
        started_at: started,
        updated_at: updated,
        metric_value: m.metric_value,
    }
}

fn event(kind: AlertRuleKind, m: &Measurement, now: Timestamp) -> AlertEvent {
    AlertEvent {
        id: Uuid::new_v4(),
        kind,
        severity: m.severity,
        title: m.title.clone(),
        message: m.message.clone(),
        context: m.context.clone(),
        timestamp: now,
        is_recovery: false,
    }
}

fn cooldown_seconds(config: &AlertRuleConfig) -> f64 {
    (config.cooldown_minutes * 60) as f64
}

fn rule_allows_notification(config: &AlertRuleConfig, runtime: &AlertRuleRuntime, severity: AlertSeverity, now: Timestamp) -> bool {
    if !config.desktop_notifications_enabled || !config.kind.supports_desktop_notifications() {
        return false;
    }
    if runtime.snoozed_until.is_some_and(|s| s > now) || runtime.dismiss_until_recovery {
        return false;
    }
    if runtime.last_notification_date.is_some_and(|l| now - l < cooldown_seconds(config)) {
        return false;
    }
    severity >= AlertSeverity::Warning
}

fn should_repeat_event(config: &AlertRuleConfig, runtime: &AlertRuleRuntime, now: Timestamp) -> bool {
    runtime.active_severity != AlertSeverity::None
        && runtime.last_event_date.is_some_and(|l| now - l >= cooldown_seconds(config))
}

pub fn evaluate(
    config: &AlertRuleConfig,
    runtime: &AlertRuleRuntime,
    input: &EvaluationInput,
    delivery: &NotificationDelivery,
) -> EvaluationOutcome {
    if !config.is_enabled {
        return outcome(runtime.reset(), None, None, false);
    }
    let m = measurement(config.kind, config, input, runtime);
    if !m.is_available() {
        let mut o = outcome(runtime.reset(), None, None, false);
        o.availability_reason = m.unavailable_reason;
        return o;
    }
    let now = input.now;
    let mut next = runtime.clone();
    next.last_metric_value = m.metric_value;

    if m.severity == AlertSeverity::None {
        next.pending_severity = AlertSeverity::None;
        next.pending_sample_count = 0;
        if runtime.active_severity != AlertSeverity::None {
            next.active_severity = AlertSeverity::None;
            next.dismiss_until_recovery = false;
            next.snoozed_until = None;
        }
        return outcome(next, None, None, false);
    }

    if runtime.dismiss_until_recovery && runtime.active_severity != AlertSeverity::None {
        next.active_severity = runtime.active_severity.max(m.severity);
        next.pending_severity = m.severity;
        next.pending_sample_count = 0;
        return outcome(next, None, None, false);
    }

    if runtime.active_severity == m.severity {
        next.pending_severity = m.severity;
        next.pending_sample_count = 0;
        let active = active_state(config.kind, m.severity, &m, runtime.last_event_date.unwrap_or(now), now);
        let notify = delivery.allows(m.severity, now) && rule_allows_notification(config, runtime, m.severity, now);
        if should_repeat_event(config, runtime, now) || notify {
            if notify {
                next.last_notification_date = Some(now);
            }
            next.last_event_date = Some(now);
            return outcome(next, Some(active), Some(event(config.kind, &m, now)), notify);
        }
        return outcome(next, Some(active), None, false);
    }

    if next.pending_severity == m.severity {
        next.pending_sample_count += 1;
    } else {
        next.pending_severity = m.severity;
        next.pending_sample_count = 1;
    }
    if next.pending_sample_count < config.debounce_samples.max(1) {
        let active = (runtime.active_severity != AlertSeverity::None).then(|| {
            active_state(config.kind, runtime.active_severity, &m, runtime.last_event_date.unwrap_or(now), now)
        });
        return outcome(next, active, None, false);
    }

    next.active_severity = m.severity;
    next.pending_sample_count = 0;
    next.pending_severity = m.severity;
    next.last_event_date = Some(now);
    let notify = delivery.allows(m.severity, now) && rule_allows_notification(config, runtime, m.severity, now);
    if notify {
        next.last_notification_date = Some(now);
    }
    let active = active_state(config.kind, m.severity, &m, now, now);
    outcome(next, Some(active), Some(event(config.kind, &m, now)), notify)
}

pub fn availability_reason(kind: AlertRuleKind, snapshot: &SystemSnapshot) -> Option<String> {
    let input = EvaluationInput {
        snapshot,
        fan_mode: FanControlMode::Automatic,
        helper_installed: true,
        helper_connection_state: HelperConnectionState::Reachable,
        helper_status_message: None,
        process_insights_enabled: true,
        now: 0.0,
    };
    measurement(kind, &AlertPreset::Default.configuration(kind), &input, &AlertRuleRuntime::initial(kind)).unavailable_reason
}

fn severity_high(value: f64, t: &AlertThreshold, active: AlertSeverity) -> AlertSeverity {
    let critical = t.critical.unwrap_or(f64::MAX);
    let warning = t.warning.unwrap_or(f64::MAX);
    if value >= critical || (active == AlertSeverity::Critical && value >= critical - t.hysteresis) {
        AlertSeverity::Critical
    } else if value >= warning || (active == AlertSeverity::Warning && value >= warning - t.hysteresis) {
        AlertSeverity::Warning
    } else {
        AlertSeverity::None
    }
}

fn severity_low(value: f64, t: &AlertThreshold, active: AlertSeverity) -> AlertSeverity {
    let critical = t.critical.unwrap_or(-f64::MAX);
    let warning = t.warning.unwrap_or(-f64::MAX);
    if value <= critical || (active == AlertSeverity::Critical && value <= critical + t.hysteresis) {
        AlertSeverity::Critical
    } else if value <= warning || (active == AlertSeverity::Warning && value <= warning + t.hysteresis) {
        AlertSeverity::Warning
    } else {
        AlertSeverity::None
    }
}

fn top_cpu_context(top: &TopProcessSnapshot, enabled: bool) -> Option<String> {
    let p = top.top_cpu.first().filter(|p| enabled && p.cpu_percent > 0.0)?;
    Some(format!("Top CPU: {} ({:.0}%)", p.name, p.cpu_percent))
}

fn top_memory_context(top: &TopProcessSnapshot, enabled: bool) -> Option<String> {
    let p = top.top_memory.first().filter(|p| enabled && p.memory_bytes > 0)?;
    Some(format!("Top Memory: {} ({:.1} GB)", p.name, p.memory_gb()))
}

fn pick(severity: AlertSeverity, critical: &'static str, other: &'static str) -> &'static str {
    if severity == AlertSeverity::Critical { critical } else { other }
}

pub fn measurement(kind: AlertRuleKind, config: &AlertRuleConfig, input: &EvaluationInput, runtime: &AlertRuleRuntime) -> Measurement {
    use AlertRuleKind::*;
    use AlertSeverity as S;
    let s = input.snapshot;
    let t = &config.threshold;
    let active = runtime.active_severity;
    let cpu_ctx = || top_cpu_context(&s.top_processes, input.process_insights_enabled);
    let mem_ctx = || top_memory_context(&s.top_processes, input.process_insights_enabled);
    match kind {
        CpuTemperature | GpuTemperature => {
            let (value, name) = if kind == CpuTemperature {
                (s.cpu_safety_temperature(), "CPU")
            } else {
                (s.gpu_safety_temperature(), "GPU")
            };
            let Some(v) = value else {
                return Measurement::unavailable(kind, &format!("{name} temperature is unavailable on this Mac."));
            };
            let sev = severity_high(v, t, active);
            let title = format!("{name} temperature is {}", if sev == S::Critical { "critical" } else { "elevated" });
            let mut m = Measurement::new(sev, Some(v), "", format!("{name} peak temperature reached {v:.0}°C."), cpu_ctx());
            m.title = title;
            m
        }
        OverallThermalState => {
            let v = s.thermal_state.level() as f64;
            let sev = severity_high(v, t, active);
            Measurement::new(
                sev,
                Some(v),
                pick(sev, "macOS reports critical thermal pressure", "macOS reports elevated thermal pressure"),
                format!("Overall thermal state is {}.", s.thermal_state.label()),
                cpu_ctx(),
            )
        }
        CpuUsage => {
            let v = s.cpu_usage_percent;
            let sev = severity_high(v, t, active);
            Measurement::new(sev, Some(v), pick(sev, "CPU usage is pinned", "CPU usage is elevated"), format!("CPU usage is {v:.0}%."), cpu_ctx())
        }
        MemoryPressure => {
            let v = s.memory_pressure.level() as f64;
            let sev = severity_high(v, t, active);
            Measurement::new(
                sev,
                Some(v),
                pick(sev, "Memory pressure is critical", "Memory pressure is elevated"),
                format!("Memory pressure is {}.", s.memory_pressure.label()),
                mem_ctx(),
            )
        }
        SwapUsage => {
            let v = s.swap_used_bytes as f64 / 1_073_741_824.0;
            let sev = severity_high(v, t, active);
            Measurement::new(sev, Some(v), pick(sev, "Swap usage is heavy", "Swap usage is growing"), format!("Swap usage reached {v:.1} GB."), mem_ctx())
        }
        FanTooLowUnderHeat => {
            if s.number_of_fans == 0 {
                return Measurement::unavailable(kind, "No fan sensors were detected on this Mac.");
            }
            let hottest = s.cpu_safety_temperature().unwrap_or(0.0).max(s.gpu_safety_temperature().unwrap_or(0.0));
            if hottest <= 0.0 {
                return Measurement::new(
                    S::None,
                    None,
                    "Fan speed is normal",
                    "Waiting for live thermal data before evaluating fan safety.".into(),
                    None,
                );
            }
            // 0 RPM is a genuine stall; -1 is a failed read and is ignored.
            if let Some(i) = s.fan_speeds.iter().position(|v| *v == 0) {
                if hottest >= t.warning.unwrap_or(0.0) {
                    return Measurement::new(
                        S::Critical,
                        Some(hottest),
                        "A fan appears stalled while the Mac is hot",
                        format!("Fan {} reported 0 RPM while the hottest sensor is {}°C.", i + 1, hottest.round() as i64),
                        None,
                    );
                }
            }
            let low = s
                .fan_speeds
                .iter()
                .zip(&s.fan_min_speeds)
                .position(|(speed, min)| *speed >= 0 && *speed < (min + 150).max(1_200));
            let sev = match low {
                Some(_) if hottest >= t.critical.unwrap_or(f64::MAX) => S::Critical,
                Some(_) if hottest >= t.warning.unwrap_or(f64::MAX) => S::Warning,
                _ => S::None,
            };
            let message = match low {
                None => "Fan speed is tracking heat normally.".to_string(),
                Some(i) => format!("Fan {} is under target while the hottest sensor is {}°C.", i + 1, hottest.round() as i64),
            };
            Measurement::new(sev, Some(hottest), pick(sev, "Fan speed is too low for current heat", "Fan safety margin is shrinking"), message, None)
        }
        BatteryTemperature => {
            if !s.battery.has_battery {
                return Measurement::unavailable(kind, "This Mac does not report a battery.");
            }
            let Some(v) = s.battery.temperature_c else {
                return Measurement::unavailable(kind, "Battery temperature is unavailable on this Mac.");
            };
            let sev = severity_high(v, t, active);
            Measurement::new(
                sev,
                Some(v),
                pick(sev, "Battery temperature is critical", "Battery temperature is elevated"),
                format!("Battery temperature reached {v:.0}°C."),
                None,
            )
        }
        BatteryHealth => {
            if !s.battery.has_battery {
                return Measurement::unavailable(kind, "This Mac does not report a battery.");
            }
            let Some(v) = s.battery.health_percent.map(|h| h as f64) else {
                return Measurement::unavailable(kind, "Battery health is unavailable on this Mac.");
            };
            let sev = severity_low(v, t, active);
            Measurement::new(
                sev,
                Some(v),
                pick(sev, "Battery health is below the critical threshold", "Battery health is below target"),
                format!("Battery health is {v:.0}%."),
                s.battery.cycle_count.map(|c| format!("{c} cycles")),
            )
        }
        LowBatteryDischarging => {
            if !s.battery.has_battery {
                return Measurement::unavailable(kind, "This Mac does not report a battery.");
            }
            if s.battery.is_plugged_in {
                return Measurement::new(
                    S::None,
                    None,
                    "Battery is not discharging",
                    "Low-battery alerts only apply while unplugged.".into(),
                    None,
                );
            }
            let v = s.battery.charge_percent.unwrap_or(100) as f64;
            let sev = severity_low(v, t, active);
            Measurement::new(
                sev,
                Some(v),
                pick(sev, "Battery is critically low", "Battery is running low"),
                format!("Battery charge is {v:.0}% while discharging."),
                s.battery.time_remaining_minutes.map(|m| format!("{m} min remaining")),
            )
        }
        SmcUnavailable => {
            let unavailable = !s.has_smc_access;
            Measurement::new(
                if unavailable { S::Critical } else { S::None },
                Some(if unavailable { 1.0 } else { 0.0 }),
                "AppleSMC access is unavailable",
                s.last_error.clone().unwrap_or_else(|| "Core-Monitor could not open AppleSMC.".into()),
                None,
            )
        }
        HelperUnavailable => {
            use HelperConnectionState as H;
            let missing_like = matches!(input.helper_connection_state, H::Missing)
                || (input.helper_connection_state == H::Unknown && !input.helper_installed);
            let sev = if !input.fan_mode.requires_privileged_helper() {
                S::None
            } else if input.helper_connection_state == H::Unreachable {
                S::Critical
            } else if missing_like {
                S::Warning
            } else {
                S::None
            };
            let message = if missing_like {
                "Install the privileged helper before using manual or managed fan modes.".to_string()
            } else {
                input
                    .helper_status_message
                    .clone()
                    .unwrap_or_else(|| "Core-Monitor cannot use the privileged fan helper for the current fan mode.".into())
            };
            Measurement::new(
                sev,
                Some(if sev == S::None { 0.0 } else { 1.0 }),
                pick(sev, "Fan helper connection failed", "Fan helper is unavailable"),
                message,
                Some(format!("Current mode: {}", input.fan_mode.title())),
            )
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn input(snapshot: &SystemSnapshot, now: f64) -> EvaluationInput<'_> {
        EvaluationInput {
            snapshot,
            fan_mode: FanControlMode::Automatic,
            helper_installed: true,
            helper_connection_state: HelperConnectionState::Reachable,
            helper_status_message: None,
            process_insights_enabled: true,
            now,
        }
    }

    fn hot(cpu: f64) -> SystemSnapshot {
        SystemSnapshot { cpu_peak_temperature: Some(cpu), has_smc_access: true, ..Default::default() }
    }

    fn run(config: &AlertRuleConfig, rt: &AlertRuleRuntime, s: &SystemSnapshot, now: f64) -> EvaluationOutcome {
        evaluate(config, rt, &input(s, now), &NotificationDelivery::default())
    }

    #[test]
    fn presets_match_swift_defaults() {
        let d = AlertPreset::Default.configuration(AlertRuleKind::CpuTemperature);
        assert_eq!((d.threshold.warning, d.threshold.critical, d.cooldown_minutes, d.debounce_samples), (Some(85.0), Some(95.0), 20, 2));
        let q = AlertPreset::Quiet.configuration(AlertRuleKind::HelperUnavailable);
        assert_eq!((q.cooldown_minutes, q.threshold.warning), (40, None));
        assert!(!AlertPreset::Quiet.configuration(AlertRuleKind::CpuUsage).desktop_notifications_enabled);
        for p in AlertPreset::ALL {
            assert_eq!(p.configurations().len(), 12);
        }
        let store = AlertStore::default();
        assert_eq!(store.notification_policy, NotificationPolicy::CriticalOnly);
    }

    #[test]
    fn debounces_then_fires_and_notifies() {
        let config = AlertPreset::Default.configuration(AlertRuleKind::CpuTemperature);
        let rt = AlertRuleRuntime::initial(config.kind);
        let first = run(&config, &rt, &hot(90.0), 0.0);
        assert!(first.event.is_none() && first.active_state.is_none());
        let second = run(&config, &first.runtime, &hot(90.0), 1.0);
        assert_eq!(second.event.as_ref().unwrap().severity, AlertSeverity::Warning);
        assert!(second.should_notify);
        assert_eq!(second.runtime.last_notification_date, Some(1.0));
        // Same severity within cooldown: active but silent.
        let third = run(&config, &second.runtime, &hot(91.0), 2.0);
        assert!(third.event.is_none() && third.active_state.is_some());
        // After cooldown the event repeats.
        let later = run(&config, &third.runtime, &hot(91.0), 1.0 + 20.0 * 60.0);
        assert!(later.event.is_some());
    }

    #[test]
    fn hysteresis_holds_until_recovery_floor() {
        let config = AlertPreset::Default.configuration(AlertRuleKind::CpuTemperature);
        let mut rt = AlertRuleRuntime::initial(config.kind);
        rt.active_severity = AlertSeverity::Warning;
        rt.last_event_date = Some(0.0);
        let held = run(&config, &rt, &hot(83.0), 10.0);
        assert_eq!(held.runtime.active_severity, AlertSeverity::Warning);
        let recovered = run(&config, &rt, &hot(81.9), 10.0);
        assert_eq!(recovered.runtime.active_severity, AlertSeverity::None);
        assert!(recovered.active_state.is_none());
    }

    #[test]
    fn dismissed_alert_stays_quiet_until_recovery() {
        let config = AlertPreset::Default.configuration(AlertRuleKind::CpuTemperature);
        let mut rt = AlertRuleRuntime::initial(config.kind);
        rt.active_severity = AlertSeverity::Warning;
        rt.dismiss_until_recovery = true;
        let o = run(&config, &rt, &hot(99.0), 0.0);
        assert!(o.event.is_none() && !o.should_notify);
        assert_eq!(o.runtime.active_severity, AlertSeverity::Critical);
        let o = run(&config, &o.runtime, &hot(40.0), 1.0);
        assert!(!o.runtime.dismiss_until_recovery);
    }

    #[test]
    fn stalled_fan_is_critical_but_failed_read_is_not() {
        let config = AlertPreset::Default.configuration(AlertRuleKind::FanTooLowUnderHeat);
        let rt = AlertRuleRuntime::initial(config.kind);
        let mut s = hot(90.0);
        s.number_of_fans = 1;
        s.fan_min_speeds = vec![1200];
        s.fan_speeds = vec![0];
        let m = measurement(config.kind, &config, &input(&s, 0.0), &rt);
        assert_eq!(m.severity, AlertSeverity::Critical);
        s.fan_speeds = vec![-1];
        assert_eq!(measurement(config.kind, &config, &input(&s, 0.0), &rt).severity, AlertSeverity::None);
        s.fan_speeds = vec![1300];
        assert_eq!(measurement(config.kind, &config, &input(&s, 0.0), &rt).severity, AlertSeverity::Warning);
        s.number_of_fans = 0;
        assert!(availability_reason(config.kind, &s).is_some());
    }

    #[test]
    fn low_battery_uses_low_value_thresholds() {
        let config = AlertPreset::Default.configuration(AlertRuleKind::LowBatteryDischarging);
        let rt = AlertRuleRuntime::initial(config.kind);
        let mut s = hot(40.0);
        s.battery.has_battery = true;
        s.battery.charge_percent = Some(9);
        assert_eq!(measurement(config.kind, &config, &input(&s, 0.0), &rt).severity, AlertSeverity::Critical);
        s.battery.is_plugged_in = true;
        assert_eq!(measurement(config.kind, &config, &input(&s, 0.0), &rt).severity, AlertSeverity::None);
    }

    #[test]
    fn helper_alert_only_for_helper_modes() {
        let config = AlertPreset::Default.configuration(AlertRuleKind::HelperUnavailable);
        let rt = AlertRuleRuntime::initial(config.kind);
        let s = hot(40.0);
        let mut i = input(&s, 0.0);
        i.helper_connection_state = HelperConnectionState::Unreachable;
        assert_eq!(measurement(config.kind, &config, &i, &rt).severity, AlertSeverity::None);
        i.fan_mode = FanControlMode::Manual;
        assert_eq!(measurement(config.kind, &config, &i, &rt).severity, AlertSeverity::Critical);
        i.helper_connection_state = HelperConnectionState::Unknown;
        i.helper_installed = false;
        assert_eq!(measurement(config.kind, &config, &i, &rt).severity, AlertSeverity::Warning);
    }

    #[test]
    fn delivery_policy_and_mute() {
        let mut d = NotificationDelivery { policy: NotificationPolicy::CriticalOnly, ..Default::default() };
        assert!(!d.allows(AlertSeverity::Warning, 0.0) && d.allows(AlertSeverity::Critical, 0.0));
        d.muted_until = Some(10.0);
        assert!(!d.allows(AlertSeverity::Critical, 5.0) && d.allows(AlertSeverity::Critical, 11.0));
    }

    #[test]
    fn disabled_rule_resets_runtime() {
        let mut config = AlertPreset::Default.configuration(AlertRuleKind::CpuUsage);
        config.is_enabled = false;
        let mut rt = AlertRuleRuntime::initial(config.kind);
        rt.active_severity = AlertSeverity::Critical;
        let o = run(&config, &rt, &hot(40.0), 0.0);
        assert_eq!(o.runtime.active_severity, AlertSeverity::None);
    }
}
