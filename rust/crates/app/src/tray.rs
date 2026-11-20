//! Menu bar status item with live readings and fan mode shortcuts.
use crate::engine::{self, SharedState};
use core_monitor_core::alerts::AlertSeverity;
use core_monitor_core::fan::FanControlMode;
use eframe::egui;
use tray_icon::menu::{CheckMenuItem, Menu, MenuEvent, MenuItem, PredefinedMenuItem, Submenu};
use tray_icon::{Icon, TrayIcon, TrayIconBuilder};

pub struct Tray {
    icon: TrayIcon,
    show: MenuItem,
    quit: MenuItem,
    modes: Vec<(FanControlMode, CheckMenuItem)>,
    title: String,
}

fn icon() -> Icon {
    const SIZE: u32 = 18;
    let mut rgba = Vec::with_capacity((SIZE * SIZE * 4) as usize);
    let c = (SIZE as f32 - 1.0) / 2.0;
    for y in 0..SIZE {
        for x in 0..SIZE {
            let d = ((x as f32 - c).powi(2) + (y as f32 - c).powi(2)).sqrt();
            let on = (5.5..=8.0).contains(&d) || d <= 2.0;
            rgba.extend_from_slice(&[0, 0, 0, if on { 255 } else { 0 }]);
        }
    }
    Icon::from_rgba(rgba, SIZE, SIZE).expect("valid icon")
}

impl Tray {
    pub fn new(shared: &SharedState) -> Result<Self, String> {
        let current = shared.lock().unwrap().settings.fan_mode.canonical();
        let show = MenuItem::new("Open Dashboard", true, None);
        let quit = MenuItem::new("Quit Core-Monitor", true, None);
        let fan_menu = Submenu::new("Fan Mode", true);
        let modes: Vec<_> = FanControlMode::SELECTABLE
            .iter()
            .map(|m| (*m, CheckMenuItem::new(m.title(), true, *m == current, None)))
            .collect();
        for (_, item) in &modes {
            fan_menu.append(item).map_err(|e| e.to_string())?;
        }
        let menu = Menu::new();
        menu.append_items(&[
            &show,
            &PredefinedMenuItem::separator(),
            &fan_menu,
            &PredefinedMenuItem::separator(),
            &quit,
        ])
        .map_err(|e| e.to_string())?;
        let icon = TrayIconBuilder::new()
            .with_menu(Box::new(menu))
            .with_icon_templated(icon())
            .with_title("—")
            .with_tooltip("Core-Monitor")
            .build()
            .map_err(|e| e.to_string())?;
        Ok(Self {
            icon,
            show,
            quit,
            modes,
            title: String::new(),
        })
    }

    /// Applies menu clicks and refreshes the status title. Returns true on Quit.
    pub fn update(&mut self, ctx: &egui::Context, shared: &SharedState) -> bool {
        let mut s = shared.lock().unwrap();
        while let Ok(event) = MenuEvent::receiver().try_recv() {
            if event.id == *self.quit.id() {
                return true;
            }
            if event.id == *self.show.id() {
                ctx.send_viewport_cmd(egui::ViewportCommand::Visible(true));
                ctx.send_viewport_cmd(egui::ViewportCommand::Focus);
            }
            if let Some((mode, _)) = self.modes.iter().find(|(_, item)| event.id == *item.id()) {
                s.settings.fan_mode = *mode;
                s.settings_dirty = true;
            }
        }
        let current = s.settings.fan_mode.canonical();
        for (mode, item) in &self.modes {
            item.set_checked(*mode == current);
        }
        let snap = &s.snapshot;
        let mut title = format!("{:.0}%", snap.cpu_usage_percent);
        if s.settings.menu_bar_shows_temperature {
            if let Some(t) = snap.cpu_safety_temperature() {
                title.push_str(&format!(" {t:.0}°"));
            }
        }
        match engine::highest_severity(&s.active_alerts) {
            AlertSeverity::Critical => title.push_str(" ‼"),
            AlertSeverity::Warning => title.push_str(" !"),
            _ => {}
        }
        if title != self.title {
            self.icon.set_title(Some(&title));
            self.title = title;
        }
        false
    }
}
