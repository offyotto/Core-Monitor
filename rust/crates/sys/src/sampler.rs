use core_monitor_core::snapshot::SystemSnapshot;

/// Produces one [`SystemSnapshot`] per call, keeping the deltas needed for
/// CPU usage, network throughput and per-process CPU between calls.
pub struct Sampler {
    #[cfg(target_os = "macos")]
    inner: imp::State,
}

impl Default for Sampler {
    fn default() -> Self {
        Self::new()
    }
}

impl Sampler {
    pub fn new() -> Self {
        Self {
            #[cfg(target_os = "macos")]
            inner: imp::State::new(),
        }
    }

    /// `now` is wall-clock seconds.
    pub fn sample(&mut self, now: f64) -> SystemSnapshot {
        #[cfg(target_os = "macos")]
        {
            self.inner.sample(now)
        }
        #[cfg(not(target_os = "macos"))]
        {
            SystemSnapshot {
                sampled_at: Some(now),
                last_error: Some("Core-Monitor hardware access is only available on macOS.".into()),
                ..Default::default()
            }
        }
    }
}

#[cfg(target_os = "macos")]
mod imp {
    use crate::macos;
    use crate::smc::Smc;
    use core_monitor_core::disk::DiskStatsCache;
    use core_monitor_core::network::NetworkCounterTracker;
    use core_monitor_core::sensors::{self, SensorSet};
    use core_monitor_core::snapshot::{NetworkStats, SystemSnapshot, TopProcessSnapshot};
    use std::collections::HashMap;

    const PROCESS_INTERVAL: f64 = 5.0;

    pub struct State {
        smc: Result<Smc, crate::Error>,
        chip: String,
        sensors: SensorSet,
        previous_ticks: Option<[u32; 4]>,
        last_cpu: f64,
        network: NetworkCounterTracker,
        disk: DiskStatsCache,
        process_times: HashMap<i32, u64>,
        process_sampled: Option<f64>,
        top: TopProcessSnapshot,
        timebase: f64,
    }

    impl State {
        pub fn new() -> Self {
            let chip = macos::chip_name();
            let sensors = sensors::sensors(&chip, macos::is_apple_silicon());
            Self {
                smc: Smc::open(),
                chip,
                sensors,
                previous_ticks: None,
                last_cpu: 0.0,
                network: NetworkCounterTracker::default(),
                disk: DiskStatsCache::default(),
                process_times: HashMap::new(),
                process_sampled: None,
                top: TopProcessSnapshot::default(),
                timebase: macos::timebase_ratio(),
            }
        }

        fn sample_processes(&mut self, now: f64) {
            if self.process_sampled.is_some_and(|t| now - t < PROCESS_INTERVAL) {
                return;
            }
            let procs = macos::processes();
            let mut cpu = HashMap::new();
            if let Some(prev) = self.process_sampled {
                let elapsed_ns = (now - prev) * 1e9;
                for (pid, _, time, _) in &procs {
                    if let Some(old) = self.process_times.get(pid) {
                        let ns = time.saturating_sub(*old) as f64 * self.timebase;
                        cpu.insert(*pid, ns / elapsed_ns * 100.0);
                    }
                }
            }
            self.process_times = procs.iter().map(|(pid, _, t, _)| (*pid, *t)).collect();
            let (top_cpu, top_memory) = macos::top(&procs, &cpu, 5);
            self.top = TopProcessSnapshot { sampled_at: Some(now), top_cpu, top_memory };
            self.process_sampled = Some(now);
        }

        pub fn sample(&mut self, now: f64) -> SystemSnapshot {
            let mut s = SystemSnapshot { sampled_at: Some(now), chip_name: self.chip.clone(), ..Default::default() };

            if let Some(ticks) = macos::cpu_ticks() {
                if let Some(prev) = self.previous_ticks {
                    if let Some(usage) = core_monitor_core::snapshot::cpu_usage_percent(prev, ticks) {
                        self.last_cpu = usage;
                    }
                }
                self.previous_ticks = Some(ticks);
            }
            s.cpu_usage_percent = self.last_cpu;

            if let Some(m) = macos::memory() {
                s.memory_usage_percent = m.stats.usage_percent;
                s.memory_used_gb = m.stats.used_gb;
                s.total_memory_gb = m.stats.total_gb;
                s.memory_pressure = m.stats.pressure;
                s.app_memory_gb = m.stats.app_gb;
                s.wired_memory_gb = m.stats.wired_gb;
                s.compressed_memory_gb = m.stats.compressed_gb;
                s.free_memory_gb = m.stats.free_gb;
                s.swap_used_bytes = m.swap_used;
                s.swap_total_bytes = m.swap_total;
            }

            s.battery = macos::battery();
            s.disk = self.disk.read(now, || macos::disk().ok_or(()));
            if let Some(counters) = macos::network_counters() {
                let (up, down) = self.network.sample(counters, now);
                s.network = NetworkStats { upload_bytes_per_second: up, download_bytes_per_second: down };
            }
            s.thermal_state = macos::thermal_state();
            self.sample_processes(now);
            s.top_processes = self.top.clone();

            match &self.smc {
                Ok(smc) => {
                    s.has_smc_access = true;
                    let read = |k: &str| smc.read(k);
                    if let Some(c) = sensors::summary(&self.sensors.cpu_keys, read) {
                        s.cpu_temperature = Some(c.average);
                        s.cpu_peak_temperature = Some(c.peak);
                    }
                    if let Some(g) = sensors::summary(&self.sensors.gpu_keys, read) {
                        s.gpu_temperature = Some(g.average);
                        s.gpu_peak_temperature = Some(g.peak);
                    }
                    if let Some((sensor, v)) = sensors::first_storage_temperature(&self.sensors.storage_sensors, read) {
                        s.ssd_temperature = Some(v);
                        s.storage_temperature_label = sensor.label.into();
                    }
                    s.number_of_fans = smc.fan_count();
                    for i in 0..s.number_of_fans {
                        // -1 marks a failed read so it is never mistaken for a stall.
                        s.fan_speeds.push(smc.read(&format!("F{i}Ac")).map_or(-1, |v| v.max(0.0).round() as i64));
                        s.fan_min_speeds.push(smc.read(&format!("F{i}Mn")).map_or(1000, |v| v.round() as i64));
                        s.fan_max_speeds.push(smc.read(&format!("F{i}Mx")).map_or(6500, |v| v.round() as i64));
                    }
                    s.cpu_power_watts = smc.read("PCPU").filter(|v| v.is_finite() && *v >= 0.0);
                    s.gpu_power_watts = smc.read("PGPU").filter(|v| v.is_finite() && *v >= 0.0);
                }
                Err(e) => s.last_error = Some(e.0.clone()),
            }
            s.total_system_watts = match (s.battery.is_plugged_in, s.battery.power_watts) {
                (false, Some(w)) => Some(w.abs()),
                _ => match (s.cpu_power_watts, s.gpu_power_watts) {
                    (None, None) => None,
                    (c, g) => Some(c.unwrap_or(0.0) + g.unwrap_or(0.0)),
                },
            };
            if s.storage_temperature_label.is_empty() {
                s.storage_temperature_label = "Storage (SMC)".into();
            }
            s
        }
    }
}
