use std::collections::BTreeMap;

pub const LEASE_DURATION: f64 = 15.0;

/// Fan ownership leases held by the helper. Ownership is recorded before a
/// hardware write so even a partially failed write is covered by recovery.
#[derive(Debug, Default, Clone)]
pub struct FanControlLease {
    entries: BTreeMap<usize, (u64, f64)>,
}

impl FanControlLease {
    pub fn fan_ids(&self) -> Vec<usize> {
        self.entries.keys().copied().collect()
    }

    pub fn can_control(&self, fan: usize, owner: u64) -> bool {
        self.entries.get(&fan).is_none_or(|(o, _)| *o == owner)
    }

    pub fn acquire(&mut self, fan: usize, owner: u64, now: f64) -> bool {
        if !self.can_control(fan, owner) {
            return false;
        }
        self.entries.insert(fan, (owner, now + LEASE_DURATION));
        true
    }

    pub fn renewed(&mut self, owner: u64, now: f64) -> bool {
        let mut renewed = false;
        for (o, expires) in self.entries.values_mut() {
            if *o == owner && *expires > now {
                *expires = now + LEASE_DURATION;
                renewed = true;
            }
        }
        renewed
    }

    pub fn release(&mut self, fan: usize) {
        self.entries.remove(&fan);
    }

    pub fn expire(&mut self, owner: u64) {
        for (o, expires) in self.entries.values_mut() {
            if *o == owner {
                *expires = 0.0;
            }
        }
    }

    /// Failed restores stay due so a transient SMC failure is retried.
    pub fn restore_expired<E>(&mut self, now: f64, mut restore: impl FnMut(usize) -> Result<(), E>) -> Vec<usize> {
        let mut failed = Vec::new();
        for fan in self.fan_ids() {
            if self.entries[&fan].1 <= now {
                match restore(fan) {
                    Ok(()) => {
                        self.entries.remove(&fan);
                    }
                    Err(_) => failed.push(fan),
                }
            }
        }
        failed
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn owner_exclusive_and_renewable() {
        let mut lease = FanControlLease::default();
        assert!(lease.acquire(0, 1, 0.0));
        assert!(!lease.acquire(0, 2, 1.0));
        assert!(lease.renewed(1, 10.0));
        assert!(!lease.renewed(2, 10.0));
        assert!(lease.restore_expired::<()>(20.0, |_| Ok(())).is_empty());
        assert_eq!(lease.fan_ids(), vec![0]);
        assert!(lease.restore_expired::<()>(25.0, |_| Ok(())).is_empty());
        assert!(lease.fan_ids().is_empty());
    }

    #[test]
    fn expired_lease_is_not_renewed_and_failed_restore_retries() {
        let mut lease = FanControlLease::default();
        lease.acquire(1, 7, 0.0);
        assert!(!lease.renewed(7, 16.0));
        assert_eq!(lease.restore_expired(16.0, |_| Err(())), vec![1]);
        assert_eq!(lease.restore_expired::<()>(17.0, |_| Ok(())), Vec::<usize>::new());
        assert!(lease.fan_ids().is_empty());
    }

    #[test]
    fn disconnect_expires_immediately() {
        let mut lease = FanControlLease::default();
        lease.acquire(0, 3, 100.0);
        lease.expire(3);
        let mut restored = vec![];
        lease.restore_expired::<()>(100.0, |id| {
            restored.push(id);
            Ok(())
        });
        assert_eq!(restored, vec![0]);
        assert!(lease.can_control(0, 4));
    }
}
