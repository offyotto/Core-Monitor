//! A single sample of everything the monitor reads.
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub enum MemoryPressure {
    #[default]
    Green,
    Yellow,
    Red,
}

impl MemoryPressure {
    pub fn level(self) -> u8 {
        self as u8
    }
    pub fn label(self) -> &'static str {
        ["Normal", "Elevated", "Critical"][self as usize]
    }
}

/// Mirrors `ProcessInfo.ThermalState`.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub enum ThermalState {
    #[default]
    Nominal,
    Fair,
    Serious,
    Critical,
}

impl ThermalState {
    pub fn level(self) -> u8 {
        self as u8
    }
    pub fn label(self) -> &'static str {
        ["Nominal", "Fair", "Serious", "Critical"][self as usize]
    }
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct BatteryInfo {
    pub has_battery: bool,
    pub charge_percent: Option<i64>,
    pub is_charging: bool,
    pub is_plugged_in: bool,
    pub power_watts: Option<f64>,
    pub cycle_count: Option<i64>,
    pub health_percent: Option<i64>,
    pub temperature_c: Option<f64>,
    pub voltage_v: Option<f64>,
    pub amperage_a: Option<f64>,
    pub current_capacity: Option<i64>,
    pub max_capacity: Option<i64>,
    pub source: Option<String>,
    pub status: Option<String>,
    pub time_remaining_minutes: Option<i64>,
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct DiskStats {
    pub total_gb: f64,
    pub used_gb: f64,
    pub free_gb: f64,
    pub purgeable_gb: f64,
    pub usage_percent: f64,
}

impl DiskStats {
    pub fn from_bytes(total: u64, available: u64, purgeable: u64) -> Self {
        const GB: f64 = 1_000_000_000.0;
        let used = total.saturating_sub(available);
        DiskStats {
            total_gb: total as f64 / GB,
            used_gb: used as f64 / GB,
            free_gb: available as f64 / GB,
            purgeable_gb: purgeable as f64 / GB,
            usage_percent: if total > 0 { used as f64 / total as f64 * 100.0 } else { 0.0 },
        }
    }
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct NetworkStats {
    pub upload_bytes_per_second: f64,
    pub download_bytes_per_second: f64,
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct ProcessActivity {
    pub pid: i32,
    pub name: String,
    pub cpu_percent: f64,
    pub memory_bytes: u64,
}

impl ProcessActivity {
    pub fn memory_gb(&self) -> f64 {
        self.memory_bytes as f64 / 1_073_741_824.0
    }
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct TopProcessSnapshot {
    pub sampled_at: Option<f64>,
    pub top_cpu: Vec<ProcessActivity>,
    pub top_memory: Vec<ProcessActivity>,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct MemoryStats {
    pub usage_percent: f64,
    pub used_gb: f64,
    pub total_gb: f64,
    pub pressure: MemoryPressure,
    pub app_gb: f64,
    pub wired_gb: f64,
    pub compressed_gb: f64,
    pub free_gb: f64,
}

/// Used memory is active + wired + compressor pages; pressure follows the
/// remaining fraction (green above 25%, yellow above 12%, red otherwise).
pub fn memory_stats(active_pages: u64, wired_pages: u64, compressed_pages: u64, page_size: u64, total_bytes: u64) -> Option<MemoryStats> {
    const GIB: f64 = 1_073_741_824.0;
    let total = total_bytes as f64;
    if total <= 0.0 {
        return None;
    }
    let page = page_size as f64;
    let (app, wired, compressed) = (active_pages as f64 * page, wired_pages as f64 * page, compressed_pages as f64 * page);
    let used = app + wired + compressed;
    let available = (total - used).max(0.0);
    let ratio = (available / total).clamp(0.0, 1.0);
    let pressure = if ratio > 0.25 {
        MemoryPressure::Green
    } else if ratio > 0.12 {
        MemoryPressure::Yellow
    } else {
        MemoryPressure::Red
    };
    Some(MemoryStats {
        usage_percent: (used / total * 100.0).clamp(0.0, 100.0),
        used_gb: used / GIB,
        total_gb: total / GIB,
        pressure,
        app_gb: app / GIB,
        wired_gb: wired / GIB,
        compressed_gb: compressed / GIB,
        free_gb: available / GIB,
    })
}

/// Wrapping-safe CPU usage from two `host_cpu_load_info` tick samples
/// (`[user, system, idle, nice]`).
pub fn cpu_usage_percent(previous: [u32; 4], current: [u32; 4]) -> Option<f64> {
    let d: Vec<f64> = (0..4).map(|i| current[i].wrapping_sub(previous[i]) as f64).collect();
    let total: f64 = d.iter().sum();
    (total > 0.0).then(|| ((d[0] + d[1] + d[3]) / total * 100.0).clamp(0.0, 100.0))
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct SystemSnapshot {
    pub sampled_at: Option<f64>,
    pub chip_name: String,
    pub cpu_temperature: Option<f64>,
    pub gpu_temperature: Option<f64>,
    pub cpu_peak_temperature: Option<f64>,
    pub gpu_peak_temperature: Option<f64>,
    /// `-1` marks a failed read; `0` is a genuine stall.
    pub fan_speeds: Vec<i64>,
    pub fan_min_speeds: Vec<i64>,
    pub fan_max_speeds: Vec<i64>,
    pub number_of_fans: usize,
    pub cpu_usage_percent: f64,
    pub performance_core_usage_percent: Option<f64>,
    pub efficiency_core_usage_percent: Option<f64>,
    pub memory_usage_percent: f64,
    pub memory_used_gb: f64,
    pub total_memory_gb: f64,
    pub memory_pressure: MemoryPressure,
    pub app_memory_gb: f64,
    pub wired_memory_gb: f64,
    pub compressed_memory_gb: f64,
    pub free_memory_gb: f64,
    pub swap_used_bytes: u64,
    pub swap_total_bytes: u64,
    pub battery: BatteryInfo,
    pub total_system_watts: Option<f64>,
    pub cpu_power_watts: Option<f64>,
    pub gpu_power_watts: Option<f64>,
    pub disk: DiskStats,
    pub ssd_temperature: Option<f64>,
    pub storage_temperature_label: String,
    pub network: NetworkStats,
    pub thermal_state: ThermalState,
    pub top_processes: TopProcessSnapshot,
    pub has_smc_access: bool,
    pub last_error: Option<String>,
}

impl SystemSnapshot {
    pub fn cpu_safety_temperature(&self) -> Option<f64> {
        self.cpu_peak_temperature.or(self.cpu_temperature)
    }
    pub fn gpu_safety_temperature(&self) -> Option<f64> {
        self.gpu_peak_temperature.or(self.gpu_temperature)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cpu_usage_handles_wrap() {
        let prev = [u32::MAX - 10, 0, 0, 0];
        let cur = [9, 0, 80, 0];
        assert_eq!(cpu_usage_percent(prev, cur), Some(20.0));
        assert_eq!(cpu_usage_percent(cur, cur), None);
    }

    #[test]
    fn safety_temperature_prefers_peak() {
        let s = SystemSnapshot { cpu_temperature: Some(60.0), cpu_peak_temperature: Some(80.0), ..Default::default() };
        assert_eq!(s.cpu_safety_temperature(), Some(80.0));
        assert_eq!(s.gpu_safety_temperature(), None);
    }

    #[test]
    fn memory_pressure_follows_available_ratio() {
        let total = 16 * 1_073_741_824u64;
        let page = 16_384u64;
        let pages = |fraction: f64| (total as f64 * fraction / page as f64) as u64;
        assert_eq!(memory_stats(pages(0.5), 0, 0, page, total).unwrap().pressure, MemoryPressure::Green);
        assert_eq!(memory_stats(pages(0.8), 0, 0, page, total).unwrap().pressure, MemoryPressure::Yellow);
        let red = memory_stats(pages(0.6), pages(0.2), pages(0.2), page, total).unwrap();
        assert_eq!((red.pressure, red.usage_percent.round()), (MemoryPressure::Red, 100.0));
        assert!(memory_stats(1, 1, 1, page, 0).is_none());
    }

    #[test]
    fn disk_stats_from_bytes() {
        let d = DiskStats::from_bytes(1_000_000_000_000, 250_000_000_000, 0);
        assert_eq!((d.used_gb, d.usage_percent), (750.0, 75.0));
    }
}
