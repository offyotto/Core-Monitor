use core_monitor_core::helper_protocol as p;
use core_monitor_sys::smc::Smc;
use std::time::{Duration, Instant};

/// Fan writes through AppleSMC, following the Swift helper's sequencing:
/// optional `Ftst` unlock, mode key to 1, then target RPM.
pub struct Fans {
    smc: Smc,
    mode_template_lower: Option<bool>,
    has_force_test: Option<bool>,
}

impl Fans {
    pub fn open() -> Result<Self, String> {
        Ok(Self { smc: Smc::open().map_err(|e| e.0)?, mode_template_lower: None, has_force_test: None })
    }

    pub fn read(&self, key: &str) -> Result<f64, String> {
        self.smc.read_strict(key).ok_or_else(|| format!("Could not read SMC key {key}"))
    }

    fn detect(&mut self) {
        if self.mode_template_lower.is_none() {
            self.mode_template_lower = Some(self.smc.key_exists("F0md"));
        }
        if self.has_force_test.is_none() {
            self.has_force_test = Some(self.smc.key_exists("Ftst"));
        }
    }

    pub fn mode_key_template(&mut self) -> &'static str {
        self.detect();
        if self.mode_template_lower == Some(true) { "F%dmd" } else { "F%dMd" }
    }

    pub fn has_force_test(&mut self) -> bool {
        self.detect();
        self.has_force_test == Some(true)
    }

    fn mode_key(&mut self, fan: usize) -> String {
        self.mode_key_template().replace("%d", &fan.to_string())
    }

    fn force_test_enabled(&mut self) -> bool {
        self.has_force_test() && self.smc.read("Ftst").is_some_and(|v| v.round() != 0.0)
    }

    fn write(&self, key: &str, value: i64) -> Result<(), String> {
        self.smc.write(key, value).map_err(|e| format!("Write {key} failed: {e}"))
    }

    fn manual_fans_excluding(&mut self, excluded: usize) -> usize {
        let count = self.smc.fan_count();
        (0..count)
            .filter(|f| *f != excluded)
            .filter(|f| {
                let key = self.mode_key(*f);
                self.smc.read(&key).is_some_and(|v| v.round() as i64 == 1)
            })
            .count()
    }

    pub fn set_manual(&mut self, fan: usize, rpm: i64) -> Result<(), String> {
        let rpm = p::validated_hardware_rpm(
            fan,
            rpm,
            self.smc.read(&format!("F{fan}Mn")).filter(|v| v.is_finite()).map(|v| v.round() as i64),
            self.smc.read(&format!("F{fan}Mx")).filter(|v| v.is_finite()).map(|v| v.round() as i64),
        )?;
        if self.has_force_test() && !self.force_test_enabled() {
            let _ = self.write("Ftst", 1);
            std::thread::sleep(Duration::from_millis(500));
        }
        let mode_key = self.mode_key(fan);
        let deadline = Instant::now() + Duration::from_secs(5);
        loop {
            match self.write(&mode_key, 1) {
                Ok(()) => break,
                Err(e) if Instant::now() >= deadline => return Err(e),
                Err(_) => std::thread::sleep(Duration::from_millis(100)),
            }
        }
        self.write(&format!("F{fan}Tg"), rpm)
    }

    pub fn set_auto(&mut self, fan: usize) -> Result<(), String> {
        let mode_key = self.mode_key(fan);
        let others_manual = self.manual_fans_excluding(fan);
        self.write(&mode_key, 0)?;
        let _ = self.write(&format!("F{fan}Tg"), 0);
        if others_manual == 0 && self.force_test_enabled() {
            self.write("Ftst", 0)?;
        }
        Ok(())
    }
}
