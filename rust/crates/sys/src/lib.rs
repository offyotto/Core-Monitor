//! Hardware access for Core-Monitor. On macOS this talks to AppleSMC through
//! IOKit and samples Mach/sysctl/libproc; elsewhere every reader reports
//! that the platform is unsupported so the rest of the workspace still builds.

#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "macos")]
pub mod smc;

mod sampler;
pub use sampler::Sampler;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Error(pub String);

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

impl std::error::Error for Error {}

pub type Result<T> = std::result::Result<T, Error>;
