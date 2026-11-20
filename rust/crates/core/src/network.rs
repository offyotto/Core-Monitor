use std::collections::HashMap;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct NetworkCounter {
    pub sent: u64,
    pub received: u64,
}

/// Converts per-interface byte counters into throughput.
#[derive(Debug, Default)]
pub struct NetworkCounterTracker {
    previous: HashMap<u16, NetworkCounter>,
    previous_time: Option<f64>,
}

impl NetworkCounterTracker {
    /// Returns `(sent, received)` bytes per second.
    pub fn sample(&mut self, counters: HashMap<u16, NetworkCounter>, time: f64) -> (f64, f64) {
        let mut rates = (0.0, 0.0);
        if let Some(prev_time) = self.previous_time.filter(|p| time > *p) {
            let (mut sent, mut received) = (0u64, 0u64);
            for (id, value) in &counters {
                // A new or reset interface gets its own baseline.
                let Some(old) = self.previous.get(id) else {
                    continue;
                };
                sent += value.sent.saturating_sub(old.sent);
                received += value.received.saturating_sub(old.received);
            }
            let elapsed = time - prev_time;
            rates = (sent as f64 / elapsed, received as f64 / elapsed);
        }
        self.previous = counters;
        self.previous_time = Some(time);
        rates
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn c(sent: u64, received: u64) -> NetworkCounter {
        NetworkCounter { sent, received }
    }

    #[test]
    fn first_sample_is_baseline_and_new_interfaces_are_ignored() {
        let mut t = NetworkCounterTracker::default();
        assert_eq!(t.sample(HashMap::from([(1, c(100, 100))]), 0.0), (0.0, 0.0));
        let rates = t.sample(
            HashMap::from([(1, c(300, 500)), (2, c(1_000_000, 1_000_000))]),
            2.0,
        );
        assert_eq!(rates, (100.0, 200.0));
    }

    #[test]
    fn counter_reset_does_not_go_negative() {
        let mut t = NetworkCounterTracker::default();
        t.sample(HashMap::from([(1, c(500, 500))]), 0.0);
        assert_eq!(t.sample(HashMap::from([(1, c(10, 10))]), 1.0), (0.0, 0.0));
        assert_eq!(t.sample(HashMap::from([(1, c(20, 10))]), 1.0), (0.0, 0.0));
    }
}
