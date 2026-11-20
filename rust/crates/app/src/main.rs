//! Core-Monitor: menu bar status item plus dashboard window.
mod engine;
mod helper_client;
mod settings;
#[cfg(target_os = "macos")]
mod tray;
mod ui;

use eframe::egui;

struct App {
    dashboard: ui::Dashboard,
    #[cfg(target_os = "macos")]
    tray: Option<tray::Tray>,
    #[cfg(target_os = "macos")]
    quitting: bool,
}

impl App {
    fn handle_close(&mut self, ctx: &egui::Context) {
        // Closing the window keeps the menu bar item running, as the Swift app did.
        #[cfg(target_os = "macos")]
        if self.tray.is_some() && !self.quitting && ctx.input(|i| i.viewport().close_requested()) {
            ctx.send_viewport_cmd(egui::ViewportCommand::CancelClose);
            ctx.send_viewport_cmd(egui::ViewportCommand::Visible(false));
        }
        #[cfg(not(target_os = "macos"))]
        let _ = ctx;
    }
}

impl eframe::App for App {
    fn logic(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.handle_close(ctx);
        #[cfg(target_os = "macos")]
        if let Some(tray) = &mut self.tray {
            if tray.update(ctx, &self.dashboard.shared) {
                self.quitting = true;
                ctx.send_viewport_cmd(egui::ViewportCommand::Close);
            }
        }
        ctx.request_repaint_after(std::time::Duration::from_secs(1));
    }

    fn ui(&mut self, ui: &mut egui::Ui, _frame: &mut eframe::Frame) {
        self.dashboard.show(ui);
    }

    fn on_exit(&mut self) {
        let shared = &self.dashboard.shared;
        shared.lock().unwrap().quit = true;
        // Give the engine one tick to hand the fans back to macOS.
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(3);
        while std::time::Instant::now() < deadline && std::sync::Arc::strong_count(shared) > 1 {
            std::thread::sleep(std::time::Duration::from_millis(50));
        }
    }
}

fn main() -> eframe::Result {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_title("Core-Monitor")
            .with_inner_size([860.0, 640.0])
            .with_min_inner_size([620.0, 420.0]),
        ..Default::default()
    };
    eframe::run_native(
        "Core-Monitor",
        options,
        Box::new(|cc| {
            let ctx = cc.egui_ctx.clone();
            let shared = engine::start(move || ctx.request_repaint());
            Ok(Box::new(App {
                #[cfg(target_os = "macos")]
                tray: tray::Tray::new(&shared).ok(),
                #[cfg(target_os = "macos")]
                quitting: false,
                dashboard: ui::Dashboard::new(shared),
            }))
        }),
    )
}
