//! Dashboard window.
use crate::engine::{self, Shared, SharedState};
use crate::settings;
use core_monitor_core::alerts::{AlertPreset, AlertSeverity, NotificationPolicy};
use core_monitor_core::fan::{CustomFanPreset, FanControlMode, MAX_SPEED, MIN_SPEED};
use core_monitor_core::format;
use core_monitor_core::trend::{SnapshotHealth, TrendRange, TrendSeries};
use eframe::egui::{self, Color32, RichText};

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Tab {
    Overview,
    Fans,
    Alerts,
    Processes,
}

pub struct Dashboard {
    pub shared: SharedState,
    tab: Tab,
    range: TrendRange,
    preset_source: String,
    preset_feedback: Vec<String>,
}

impl Dashboard {
    pub fn new(shared: SharedState) -> Self {
        let source = shared
            .lock()
            .unwrap()
            .preset
            .clone()
            .unwrap_or_else(CustomFanPreset::starter)
            .to_pretty_json();
        Self {
            shared,
            tab: Tab::Overview,
            range: TrendRange::FiveMinutes,
            preset_source: source,
            preset_feedback: Vec::new(),
        }
    }

    pub fn show(&mut self, ui: &mut egui::Ui) {
        let shared = self.shared.clone();
        let mut s = shared.lock().unwrap();
        egui::Panel::top("tabs").show(ui, |ui| {
            ui.horizontal(|ui| {
                for (tab, title) in [
                    (Tab::Overview, "Overview"),
                    (Tab::Fans, "Fans"),
                    (Tab::Alerts, "Alerts"),
                    (Tab::Processes, "Processes"),
                ] {
                    ui.selectable_value(&mut self.tab, tab, title);
                }
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    let health = SnapshotHealth::new(
                        s.snapshot.sampled_at,
                        s.settings.refresh_interval_seconds,
                        engine::now(),
                    );
                    ui.label(format!(
                        "{} · {}",
                        health.status_label(),
                        health.age_description()
                    ));
                });
            });
        });
        egui::CentralPanel::default_margins().show(ui, |ui| {
            egui::ScrollArea::vertical().show(ui, |ui| match self.tab {
                Tab::Overview => self.overview(ui, &s),
                Tab::Fans => self.fans(ui, &mut s),
                Tab::Alerts => alerts(ui, &mut s),
                Tab::Processes => processes(ui, &s),
            });
        });
    }

    fn overview(&mut self, ui: &mut egui::Ui, s: &Shared) {
        let snap = &s.snapshot;
        ui.horizontal(|ui| {
            ui.heading(if snap.chip_name.is_empty() {
                "Core-Monitor"
            } else {
                &snap.chip_name
            });
            ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                for range in TrendRange::ALL.iter().rev() {
                    ui.selectable_value(&mut self.range, *range, range.title());
                }
            });
        });
        if let Some(err) = &snap.last_error {
            ui.colored_label(Color32::from_rgb(230, 160, 40), err);
        }
        let t = engine::now();
        egui::Grid::new("overview")
            .num_columns(3)
            .spacing([16.0, 10.0])
            .show(ui, |ui| {
                metric(
                    ui,
                    "CPU",
                    format!("{:.0}%", snap.cpu_usage_percent),
                    &s.trends.cpu_usage,
                    self.range,
                    t,
                );
                metric(
                    ui,
                    "CPU temperature",
                    temp(snap.cpu_temperature),
                    &s.trends.cpu_temperature,
                    self.range,
                    t,
                );
                metric(
                    ui,
                    "GPU temperature",
                    temp(snap.gpu_temperature),
                    &s.trends.gpu_temperature,
                    self.range,
                    t,
                );
                metric(
                    ui,
                    "Memory",
                    format!(
                        "{:.1} / {:.0} GB · {}",
                        snap.memory_used_gb,
                        snap.total_memory_gb,
                        snap.memory_pressure.label()
                    ),
                    &s.trends.memory,
                    self.range,
                    t,
                );
                metric(
                    ui,
                    "Download",
                    format::compact_rate(snap.network.download_bytes_per_second),
                    &s.trends.download,
                    self.range,
                    t,
                );
                metric(
                    ui,
                    "Upload",
                    format::compact_rate(snap.network.upload_bytes_per_second),
                    &s.trends.upload,
                    self.range,
                    t,
                );
                metric(
                    ui,
                    "Power",
                    snap.total_system_watts
                        .map_or("—".into(), |w| format!("{w:.1} W")),
                    &s.trends.power,
                    self.range,
                    t,
                );
            });
        ui.separator();
        egui::Grid::new("details")
            .num_columns(2)
            .striped(true)
            .show(ui, |ui| {
                row(ui, "Thermal state", snap.thermal_state.label().into());
                row(
                    ui,
                    "Swap",
                    format!("{:.2} GB", snap.swap_used_bytes as f64 / 1_073_741_824.0),
                );
                row(
                    ui,
                    "Compressed / wired",
                    format!(
                        "{:.1} / {:.1} GB",
                        snap.compressed_memory_gb, snap.wired_memory_gb
                    ),
                );
                row(
                    ui,
                    "Disk",
                    format!(
                        "{:.0} of {:.0} GB used ({:.0}%)",
                        snap.disk.used_gb, snap.disk.total_gb, snap.disk.usage_percent
                    ),
                );
                if let Some(t) = snap.ssd_temperature {
                    row(ui, &snap.storage_temperature_label, format!("{t:.1} °C"));
                }
                row(
                    ui,
                    "CPU / GPU power",
                    format!(
                        "{} / {}",
                        watts(snap.cpu_power_watts),
                        watts(snap.gpu_power_watts)
                    ),
                );
                let b = &snap.battery;
                if b.has_battery {
                    row(
                        ui,
                        "Battery",
                        format!(
                            "{}% · {}",
                            b.charge_percent.unwrap_or(0),
                            format::power_state(b.is_charging, b.is_plugged_in)
                        ),
                    );
                    if let Some(r) = format::runtime_description(
                        b.is_charging,
                        b.is_plugged_in,
                        b.time_remaining_minutes,
                    ) {
                        row(ui, "Runtime", r);
                    }
                    row(
                        ui,
                        "Health / cycles",
                        format!(
                            "{} / {}",
                            b.health_percent.map_or("—".into(), |h| format!("{h}%")),
                            b.cycle_count.map_or("—".into(), |c| c.to_string())
                        ),
                    );
                    row(ui, "Battery temperature", temp(b.temperature_c));
                }
                for (i, rpm) in snap.fan_speeds.iter().enumerate() {
                    let text = if *rpm < 0 {
                        "read failed".into()
                    } else {
                        format!("{rpm} RPM")
                    };
                    row(ui, &format!("Fan {}", i + 1), text);
                }
            });
    }

    fn fans(&mut self, ui: &mut egui::Ui, s: &mut Shared) {
        ui.heading("Fan control");
        ui.label(s.settings.fan_mode.summary());
        let mut mode = s.settings.fan_mode.canonical();
        egui::ComboBox::from_label("Mode")
            .selected_text(mode.title())
            .show_ui(ui, |ui| {
                for m in FanControlMode::SELECTABLE {
                    ui.selectable_value(&mut mode, m, m.title());
                }
            });
        if mode != s.settings.fan_mode.canonical() {
            s.settings.fan_mode = mode;
            s.settings_dirty = true;
        }
        let mut changed = false;
        match mode {
            FanControlMode::Manual => {
                changed |= ui
                    .add(
                        egui::Slider::new(&mut s.settings.manual_speed, MIN_SPEED..=MAX_SPEED)
                            .text("RPM")
                            .step_by(50.0),
                    )
                    .changed();
            }
            FanControlMode::Smart => {
                changed |= ui
                    .add(
                        egui::Slider::new(&mut s.settings.auto_aggressiveness, 0.0..=3.0)
                            .text("Aggressiveness"),
                    )
                    .changed();
                changed |= ui
                    .add(
                        egui::Slider::new(&mut s.settings.auto_max_speed, MIN_SPEED..=MAX_SPEED)
                            .text("Max RPM")
                            .step_by(50.0),
                    )
                    .changed();
            }
            FanControlMode::Custom => self.preset_editor(ui, s),
            _ => {}
        }
        s.settings_dirty |= changed;
        ui.separator();
        ui.label(RichText::new(&s.fan_status).monospace());
        ui.label(format!("Helper: {:?}", s.helper_state));
        if let Some(msg) = &s.helper_message {
            ui.colored_label(Color32::from_rgb(230, 160, 40), msg);
        }
        if mode.requires_privileged_helper() {
            ui.small("Core-Monitor returns the fans to macOS when you switch to System, quit, or the app stops renewing its lease.");
        }
        ui.separator();
        let snap = &s.snapshot;
        egui::Grid::new("fans")
            .num_columns(4)
            .striped(true)
            .show(ui, |ui| {
                for h in ["Fan", "Current", "Min", "Max"] {
                    ui.strong(h);
                }
                ui.end_row();
                for i in 0..snap.number_of_fans {
                    ui.label(format!("Fan {}", i + 1));
                    ui.label(snap.fan_speeds.get(i).map_or("—".into(), |v| {
                        if *v < 0 {
                            "read failed".into()
                        } else {
                            v.to_string()
                        }
                    }));
                    ui.label(
                        snap.fan_min_speeds
                            .get(i)
                            .map_or("—".into(), |v| v.to_string()),
                    );
                    ui.label(
                        snap.fan_max_speeds
                            .get(i)
                            .map_or("—".into(), |v| v.to_string()),
                    );
                    ui.end_row();
                }
            });
    }

    fn preset_editor(&mut self, ui: &mut egui::Ui, s: &mut Shared) {
        ui.label(format!(
            "Preset file: {}",
            settings::preset_path().display()
        ));
        if let Some(err) = &s.preset_error {
            ui.colored_label(Color32::LIGHT_RED, err);
        }
        ui.add(
            egui::TextEdit::multiline(&mut self.preset_source)
                .code_editor()
                .desired_rows(18)
                .desired_width(f32::INFINITY),
        );
        ui.horizontal(|ui| {
            if ui.button("Validate").clicked() {
                self.preset_feedback = match CustomFanPreset::from_json(&self.preset_source) {
                    Ok(p) => p.validation_errors(MIN_SPEED, MAX_SPEED),
                    Err(e) => vec![e],
                };
                if self.preset_feedback.is_empty() {
                    self.preset_feedback.push("Preset is valid.".into());
                }
            }
            if ui.button("Save").clicked() {
                match settings::save_preset_source(&self.preset_source) {
                    Ok(p) => {
                        self.preset_feedback = vec![format!("Saved \"{}\".", p.name)];
                        self.preset_source = p.to_pretty_json();
                        s.preset = Some(p);
                        s.preset_error = None;
                    }
                    Err(errors) => self.preset_feedback = errors,
                }
            }
            if ui.button("Load starter").clicked() {
                self.preset_source = CustomFanPreset::starter().to_pretty_json();
            }
        });
        for line in &self.preset_feedback {
            ui.label(line);
        }
    }
}

fn alerts(ui: &mut egui::Ui, s: &mut Shared) {
    ui.heading("Alerts");
    let mut preset = s.alerts.selected_preset;
    egui::ComboBox::from_label("Preset")
        .selected_text(preset.title())
        .show_ui(ui, |ui| {
            for p in AlertPreset::ALL {
                ui.selectable_value(&mut preset, p, p.title())
                    .on_hover_text(p.subtitle());
            }
        });
    if preset != s.alerts.selected_preset {
        s.alerts.apply_preset(preset);
        s.alerts_dirty = true;
    }
    let mut policy = s.alerts.notification_policy;
    egui::ComboBox::from_label("Desktop notifications")
        .selected_text(policy.title())
        .show_ui(ui, |ui| {
            for p in [
                NotificationPolicy::InAppOnly,
                NotificationPolicy::CriticalOnly,
                NotificationPolicy::WarningsAndCritical,
            ] {
                ui.selectable_value(&mut policy, p, p.title());
            }
        });
    if policy != s.alerts.notification_policy {
        s.alerts.notification_policy = policy;
        s.alerts_dirty = true;
    }
    ui.separator();
    if s.active_alerts.is_empty() {
        ui.label("No active alerts.");
    }
    let now = engine::now();
    for alert in s.active_alerts.clone() {
        ui.horizontal(|ui| {
            ui.colored_label(severity_color(alert.severity), alert.severity.title());
            ui.strong(&alert.title);
            ui.label(&alert.message);
            if let Some(ctx) = &alert.context {
                ui.weak(ctx);
            }
            if let Some(rt) = s.alerts.runtimes.iter_mut().find(|r| r.kind == alert.kind) {
                if ui.small_button("Snooze 1h").clicked() {
                    rt.snoozed_until = Some(now + 3600.0);
                    s.alerts_dirty = true;
                }
                if ui.small_button("Dismiss").clicked() {
                    rt.dismiss_until_recovery = true;
                    s.alerts_dirty = true;
                }
            }
        });
    }
    ui.separator();
    ui.collapsing("Rules", |ui| {
        egui::Grid::new("rules")
            .num_columns(4)
            .striped(true)
            .show(ui, |ui| {
                for config in s.alerts.rule_configs.iter_mut() {
                    s.alerts_dirty |= ui
                        .checkbox(&mut config.is_enabled, config.kind.title())
                        .changed();
                    if config.kind.supports_threshold_editing() {
                        let unit = config.kind.unit_label().unwrap_or("");
                        for (label, value) in [
                            ("warn", &mut config.threshold.warning),
                            ("crit", &mut config.threshold.critical),
                        ] {
                            if let Some(v) = value {
                                s.alerts_dirty |= ui
                                    .add(
                                        egui::DragValue::new(v)
                                            .prefix(format!("{label} "))
                                            .suffix(unit),
                                    )
                                    .changed();
                            } else {
                                ui.label("—");
                            }
                        }
                    } else {
                        ui.label("");
                        ui.label("");
                    }
                    ui.weak(config.kind.subtitle());
                    ui.end_row();
                }
            });
    });
    for (kind, reason) in &s.unavailable_alerts {
        ui.weak(format!("{}: {reason}", kind.title()));
    }
    ui.collapsing(format!("History ({})", s.alerts.history.len()), |ui| {
        for e in &s.alerts.history {
            ui.horizontal(|ui| {
                ui.colored_label(severity_color(e.severity), e.severity.title());
                ui.label(&e.title);
                ui.weak(&e.message);
            });
        }
    });
}

fn processes(ui: &mut egui::Ui, s: &Shared) {
    let top = &s.snapshot.top_processes;
    for (title, list, mem) in [
        ("Top CPU", &top.top_cpu, false),
        ("Top memory", &top.top_memory, true),
    ] {
        ui.heading(title);
        egui::Grid::new(title)
            .num_columns(3)
            .striped(true)
            .show(ui, |ui| {
                for p in list.iter() {
                    ui.label(&p.name);
                    ui.label(p.pid.to_string());
                    ui.label(if mem {
                        format!("{:.2} GB", p.memory_gb())
                    } else {
                        format!("{:.1}%", p.cpu_percent)
                    });
                    ui.end_row();
                }
            });
    }
}

fn severity_color(severity: AlertSeverity) -> Color32 {
    match severity {
        AlertSeverity::Critical => Color32::from_rgb(235, 80, 70),
        AlertSeverity::Warning => Color32::from_rgb(240, 175, 50),
        _ => Color32::GRAY,
    }
}

fn temp(v: Option<f64>) -> String {
    v.map_or("—".into(), |t| format!("{t:.1} °C"))
}

fn watts(v: Option<f64>) -> String {
    v.map_or("—".into(), |w| format!("{w:.1} W"))
}

fn row(ui: &mut egui::Ui, label: &str, value: String) {
    ui.label(label);
    ui.label(value);
    ui.end_row();
}

fn metric(
    ui: &mut egui::Ui,
    label: &str,
    value: String,
    series: &TrendSeries,
    range: TrendRange,
    now: f64,
) {
    ui.label(label);
    ui.strong(value);
    sparkline(ui, series, range, now);
    ui.end_row();
}

fn sparkline(ui: &mut egui::Ui, series: &TrendSeries, range: TrendRange, now: f64) {
    let (rect, _) = ui.allocate_exact_size(egui::vec2(220.0, 32.0), egui::Sense::hover());
    let points = TrendSeries::decimated(&series.points_in(range, now), 120);
    if points.len() < 2 {
        return;
    }
    let (lo, hi) = points.iter().fold((f64::MAX, f64::MIN), |(lo, hi), p| {
        (lo.min(p.value), hi.max(p.value))
    });
    let span = (hi - lo).max(1e-6);
    let start = now - range.duration();
    let line: Vec<egui::Pos2> = points
        .iter()
        .map(|p| {
            let x = rect.left() + ((p.timestamp - start) / range.duration()) as f32 * rect.width();
            let y = rect.bottom() - ((p.value - lo) / span) as f32 * rect.height();
            egui::pos2(x, y)
        })
        .collect();
    ui.painter().add(egui::Shape::line(
        line,
        egui::Stroke::new(1.5, Color32::from_rgb(90, 170, 250)),
    ));
}
