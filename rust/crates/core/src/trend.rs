//! Rolling metric history and sample freshness.
use crate::Timestamp;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TrendRange {
    OneMinute,
    FiveMinutes,
    FifteenMinutes,
}

impl TrendRange {
    pub const ALL: [TrendRange; 3] = [Self::OneMinute, Self::FiveMinutes, Self::FifteenMinutes];
    pub fn title(self) -> &'static str {
        ["1m", "5m", "15m"][self as usize]
    }
    pub fn duration(self) -> f64 {
        [60.0, 300.0, 900.0][self as usize]
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Freshness {
    Waiting,
    Live,
    Delayed,
    Stale,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct SnapshotHealth {
    pub freshness: Freshness,
    pub age: Option<f64>,
    pub expected_interval: f64,
}

impl SnapshotHealth {
    pub fn new(sampled_at: Option<Timestamp>, expected_interval: f64, now: Timestamp) -> Self {
        let expected_interval = expected_interval.max(1.0);
        let Some(sampled_at) = sampled_at else {
            return Self { freshness: Freshness::Waiting, age: None, expected_interval };
        };
        let age = (now - sampled_at).max(0.0);
        let freshness = if age <= (expected_interval * 1.5).max(2.5) {
            Freshness::Live
        } else if age <= (expected_interval * 4.0).max(12.0) {
            Freshness::Delayed
        } else {
            Freshness::Stale
        };
        Self { freshness, age: Some(age), expected_interval }
    }

    pub fn status_label(&self) -> &'static str {
        match self.freshness {
            Freshness::Waiting => "Waiting",
            Freshness::Live => "Live",
            Freshness::Delayed => "Delayed",
            Freshness::Stale => "Stale",
        }
    }

    pub fn age_description(&self) -> String {
        match self.age {
            None => "Waiting for the first sample".into(),
            Some(a) if a < 1.5 => "Updated just now".into(),
            Some(a) => format!("Updated {} ago", compact_duration(a)),
        }
    }
}

pub fn compact_duration(interval: f64) -> String {
    let rounded = (interval.round() as i64).max(1);
    match (rounded / 60, rounded % 60) {
        (0, s) => format!("{s}s"),
        (m, 0) => format!("{m}m"),
        (m, s) => format!("{m}m {s}s"),
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct TrendPoint {
    pub timestamp: Timestamp,
    pub value: f64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct TrendSummary {
    pub latest: f64,
    pub minimum: f64,
    pub maximum: f64,
    pub average: f64,
    pub delta: f64,
}

#[derive(Clone, Debug)]
pub struct TrendSeries {
    pub points: Vec<TrendPoint>,
    pub retention: f64,
}

impl Default for TrendSeries {
    fn default() -> Self {
        Self { points: Vec::new(), retention: TrendRange::FifteenMinutes.duration() }
    }
}

impl TrendSeries {
    pub fn append(&mut self, value: Option<f64>, timestamp: Timestamp) {
        let cutoff = timestamp - self.retention;
        self.points.retain(|p| p.timestamp >= cutoff);
        if let Some(value) = value {
            self.points.push(TrendPoint { timestamp, value });
        }
    }

    pub fn points_in(&self, range: TrendRange, now: Timestamp) -> Vec<TrendPoint> {
        let cutoff = now - range.duration();
        self.points.iter().copied().filter(|p| p.timestamp >= cutoff).collect()
    }

    pub fn values(&self, range: TrendRange, now: Timestamp) -> Vec<f64> {
        self.points_in(range, now).iter().map(|p| p.value).collect()
    }

    pub fn summary(&self, range: TrendRange, now: Timestamp) -> Option<TrendSummary> {
        let v = self.values(range, now);
        let (first, last) = (*v.first()?, *v.last()?);
        Some(TrendSummary {
            latest: last,
            minimum: v.iter().copied().fold(f64::INFINITY, f64::min),
            maximum: v.iter().copied().fold(f64::NEG_INFINITY, f64::max),
            average: v.iter().sum::<f64>() / v.len() as f64,
            delta: last - first,
        })
    }

    /// Min/max bucket decimation that keeps spikes visible in small charts.
    pub fn decimated(points: &[TrendPoint], max_points: usize) -> Vec<TrendPoint> {
        if max_points < 4 || points.len() <= max_points {
            return points.to_vec();
        }
        let count = points.len();
        let buckets = max_points / 2;
        let mut result = vec![points[0]];
        for bucket in 0..buckets {
            let (start, end) = (bucket * count / buckets, (bucket + 1) * count / buckets);
            if start >= end {
                continue;
            }
            let (mut lo, mut hi) = (start, start);
            for i in start + 1..end {
                if points[i].value < points[lo].value {
                    lo = i;
                }
                if points[i].value > points[hi].value {
                    hi = i;
                }
            }
            for i in [lo.min(hi), lo.max(hi)] {
                if i > 0 && points[i].timestamp != result[result.len() - 1].timestamp {
                    result.push(points[i]);
                }
            }
        }
        let last = points[count - 1];
        if last.timestamp != result[result.len() - 1].timestamp {
            result.push(last);
        }
        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn freshness_thresholds() {
        assert_eq!(SnapshotHealth::new(None, 1.0, 0.0).freshness, Freshness::Waiting);
        assert_eq!(SnapshotHealth::new(Some(0.0), 1.0, 2.5).freshness, Freshness::Live);
        assert_eq!(SnapshotHealth::new(Some(0.0), 1.0, 12.0).freshness, Freshness::Delayed);
        assert_eq!(SnapshotHealth::new(Some(0.0), 1.0, 12.1).freshness, Freshness::Stale);
        assert_eq!(SnapshotHealth::new(Some(0.0), 5.0, 30.0).age_description(), "Updated 30s ago");
        assert_eq!(compact_duration(125.0), "2m 5s");
    }

    #[test]
    fn series_trims_and_summarizes() {
        let mut s = TrendSeries::default();
        s.append(Some(10.0), 0.0);
        s.append(Some(30.0), 600.0);
        s.append(None, 960.0);
        assert_eq!(s.points.len(), 1);
        s.append(Some(20.0), 961.0);
        let sum = s.summary(TrendRange::FifteenMinutes, 961.0).unwrap();
        assert_eq!((sum.latest, sum.minimum, sum.maximum, sum.average, sum.delta), (20.0, 20.0, 30.0, 25.0, -10.0));
        assert!(s.summary(TrendRange::OneMinute, 2000.0).is_none());
    }

    #[test]
    fn decimation_keeps_extremes_and_endpoints() {
        let pts: Vec<TrendPoint> = (0..100)
            .map(|i| TrendPoint { timestamp: i as f64, value: if i == 37 { 99.0 } else { 1.0 } })
            .collect();
        let d = TrendSeries::decimated(&pts, 10);
        assert!(d.len() <= 12);
        assert_eq!(d.first().unwrap().timestamp, 0.0);
        assert_eq!(d.last().unwrap().timestamp, 99.0);
        assert!(d.iter().any(|p| p.value == 99.0));
        assert_eq!(TrendSeries::decimated(&pts[..5], 10).len(), 5);
    }
}
