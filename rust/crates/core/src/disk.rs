use crate::snapshot::DiskStats;

pub const MINIMUM_REFRESH_INTERVAL: f64 = 30.0;

pub fn should_refresh(last_updated: Option<f64>, now: f64, minimum_interval: f64) -> bool {
    last_updated.is_none_or(|last| now - last >= minimum_interval)
}

/// Keeps the last good reading when a capacity refresh fails.
#[derive(Debug, Default)]
pub struct DiskStatsCache {
    pub stats: DiskStats,
    pub last_updated: Option<f64>,
}

impl DiskStatsCache {
    pub fn read<E>(&mut self, now: f64, load: impl FnOnce() -> Result<DiskStats, E>) -> DiskStats {
        if should_refresh(self.last_updated, now, MINIMUM_REFRESH_INTERVAL) {
            if let Ok(stats) = load() {
                self.stats = stats;
                self.last_updated = Some(now);
            }
        }
        self.stats.clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn caches_and_retries_failures() {
        let mut cache = DiskStatsCache::default();
        let good = DiskStats { total_gb: 100.0, free_gb: 40.0, ..Default::default() };
        assert_eq!(cache.read::<()>(0.0, || Ok(good.clone())), good);
        assert_eq!(cache.read::<()>(10.0, || panic!("not due")), good);
        assert_eq!(cache.read(31.0, || Err(())), good);
        let newer = DiskStats { total_gb: 100.0, free_gb: 30.0, ..Default::default() };
        assert_eq!(cache.read::<()>(32.0, || Ok(newer.clone())), newer);
    }
}
