//! Platform-independent core of Core-Monitor: data models, SMC value codecs,
//! alert evaluation, fan profiles and formatting. Everything here is pure and
//! unit-tested on any host; hardware access lives in `core-monitor-sys`.

pub mod alerts;
pub mod disk;
pub mod fan;
pub mod fan_detection;
pub mod format;
pub mod helper_protocol;
pub mod lease;
pub mod network;
pub mod sensors;
pub mod smc;
pub mod snapshot;
pub mod trend;

/// Seconds on a monotonic or wall clock, depending on the caller.
pub type Timestamp = f64;
