//! SMC temperature sensor catalog per chip generation.

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct StorageSensor {
    pub key: &'static str,
    pub label: &'static str,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SensorSet {
    pub cpu_keys: Vec<&'static str>,
    pub gpu_keys: Vec<&'static str>,
    pub storage_sensors: Vec<StorageSensor>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct TemperatureSummary {
    pub average: f64,
    pub peak: f64,
}

const INTEL_CPU: &[&str] = &[
    "TC0P", "TCXC", "TC0E", "TC0F", "TC0D", "TC1C", "TC2C", "TC3C", "TC4C",
];
const INTEL_GPU: &[&str] = &["TGDD", "TG0P", "TG0D", "TG0E", "TG0F"];
const M1_CPU: &[&str] = &[
    "Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b",
];
const M1_GPU: &[&str] = &["Tg05", "Tg0D", "Tg0L", "Tg0T"];
const M2_CPU: &[&str] = &[
    "Tp1h", "Tp1t", "Tp1p", "Tp1l", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j",
];
const M2_GPU: &[&str] = &["Tg0f", "Tg0j"];
const M3_CPU: &[&str] = &[
    "Te05", "Te0L", "Te0P", "Te0S", "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E", "Tf44", "Tf49",
    "Tf4A", "Tf4B", "Tf4D", "Tf4E",
];
const M3_GPU: &[&str] = &[
    "Tf14", "Tf18", "Tf19", "Tf1A", "Tf24", "Tf28", "Tf29", "Tf2A",
];
const M4_CPU: &[&str] = &[
    "Te05", "Te0S", "Te09", "Te0H", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e",
];
const M4_GPU: &[&str] = &[
    "Tg0G", "Tg0H", "Tg1U", "Tg1k", "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k",
];
const M5_CPU: &[&str] = &[
    "Tp00", "Tp04", "Tp08", "Tp0C", "Tp0G", "Tp0K", "Tp0O", "Tp0R", "Tp0U", "Tp0X", "Tp0a", "Tp0d",
    "Tp0g", "Tp0j", "Tp0m", "Tp0p", "Tp0u", "Tp0y",
];
const M5_GPU: &[&str] = &[
    "Tg0U", "Tg0X", "Tg0d", "Tg0g", "Tg0j", "Tg1Y", "Tg1c", "Tg1g",
];

fn unique(lists: &[&[&'static str]]) -> Vec<&'static str> {
    let mut out: Vec<&'static str> = Vec::new();
    for key in lists.iter().flat_map(|l| l.iter()) {
        if !out.contains(key) {
            out.push(key);
        }
    }
    out
}

pub fn generation(chip_name: &str) -> Option<u8> {
    let upper = chip_name.to_uppercase();
    let tokens: Vec<&str> = upper.split(|c: char| !c.is_alphanumeric()).collect();
    (1..=5u8).find(|g| tokens.contains(&format!("M{g}").as_str()))
}

pub fn sensors(chip_name: &str, is_apple_silicon: bool) -> SensorSet {
    if !is_apple_silicon {
        return SensorSet {
            cpu_keys: INTEL_CPU.to_vec(),
            gpu_keys: INTEL_GPU.to_vec(),
            storage_sensors: ["A", "B", "C"]
                .iter()
                .map(|d| StorageSensor {
                    key: match *d {
                        "A" => "TH0A",
                        "B" => "TH0B",
                        _ => "TH0C",
                    },
                    label: match *d {
                        "A" => "Drive A (SMC)",
                        "B" => "Drive B (SMC)",
                        _ => "Drive C (SMC)",
                    },
                })
                .collect(),
        };
    }
    let (cpu, gpu) = match generation(chip_name) {
        Some(1) => (M1_CPU.to_vec(), M1_GPU.to_vec()),
        Some(2) => (M2_CPU.to_vec(), M2_GPU.to_vec()),
        Some(3) => (M3_CPU.to_vec(), M3_GPU.to_vec()),
        Some(4) => (M4_CPU.to_vec(), M4_GPU.to_vec()),
        Some(5) => (M5_CPU.to_vec(), M5_GPU.to_vec()),
        _ => (
            unique(&[M1_CPU, M2_CPU, M3_CPU, M4_CPU, M5_CPU]),
            unique(&[M1_GPU, M2_GPU, M3_GPU, M4_GPU, M5_GPU]),
        ),
    };
    SensorSet {
        cpu_keys: cpu,
        gpu_keys: gpu,
        storage_sensors: vec![StorageSensor {
            key: "TH0x",
            label: "NAND (SMC)",
        }],
    }
}

fn valid(value: f64, upper: f64) -> bool {
    value.is_finite() && value > 0.0 && value < upper
}

pub fn summary(
    keys: &[&str],
    mut read: impl FnMut(&str) -> Option<f64>,
) -> Option<TemperatureSummary> {
    let values: Vec<f64> = keys
        .iter()
        .filter_map(|k| read(k))
        .filter(|v| valid(*v, 150.0))
        .collect();
    let peak = values
        .iter()
        .copied()
        .fold(None, |m: Option<f64>, v| Some(m.map_or(v, |m| m.max(v))))?;
    Some(TemperatureSummary {
        average: values.iter().sum::<f64>() / values.len() as f64,
        peak,
    })
}

pub fn first_storage_temperature(
    sensors: &[StorageSensor],
    mut read: impl FnMut(&str) -> Option<f64>,
) -> Option<(StorageSensor, f64)> {
    sensors.iter().find_map(|s| {
        read(s.key)
            .filter(|v| valid(*v, 100.0))
            .map(|v| (s.clone(), v))
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn picks_generation_by_token() {
        assert_eq!(generation("Apple M3 Pro"), Some(3));
        assert_eq!(generation("Apple M10"), None);
        assert_eq!(sensors("Apple M1 Max", true).gpu_keys, M1_GPU.to_vec());
        assert_eq!(sensors("Intel Core i9", false).cpu_keys[0], "TC0P");
    }

    #[test]
    fn unknown_generation_uses_deduplicated_union() {
        let set = sensors("Apple Silicon", true);
        assert_eq!(set.cpu_keys.iter().filter(|k| **k == "Tp01").count(), 1);
        assert!(set.cpu_keys.contains(&"Tp0y") && set.gpu_keys.contains(&"Tg1g"));
    }

    #[test]
    fn summary_ignores_invalid_values() {
        let s = summary(&["a", "b", "c", "d"], |k| match k {
            "a" => Some(40.0),
            "b" => Some(60.0),
            "c" => Some(200.0),
            _ => Some(f64::NAN),
        })
        .unwrap();
        assert_eq!((s.average, s.peak), (50.0, 60.0));
        assert!(summary(&["a"], |_| Some(0.0)).is_none());
    }

    #[test]
    fn storage_temperature_skips_out_of_range() {
        let set = sensors("x", false).storage_sensors;
        let (s, v) =
            first_storage_temperature(&set, |k| if k == "TH0A" { Some(120.0) } else { Some(41.0) })
                .unwrap();
        assert_eq!((s.key, v), ("TH0B", 41.0));
    }
}
