//! Client for the privileged smc-helper socket.
use core_monitor_core::alerts::HelperConnectionState;
use core_monitor_core::helper_protocol::{Request, Response, SOCKET_PATH};
use std::io::{BufRead, BufReader, Write};
use std::path::Path;
use std::time::Duration;

#[cfg(unix)]
use std::os::unix::net::UnixStream;

pub struct HelperClient {
    #[cfg(unix)]
    connection: Option<(UnixStream, BufReader<UnixStream>)>,
    pub state: HelperConnectionState,
    pub last_error: Option<String>,
}

impl Default for HelperClient {
    fn default() -> Self {
        Self {
            #[cfg(unix)]
            connection: None,
            state: HelperConnectionState::Unknown,
            last_error: None,
        }
    }
}

impl HelperClient {
    pub fn is_installed() -> bool {
        Path::new(SOCKET_PATH).exists()
    }

    #[cfg(unix)]
    fn ensure_connected(&mut self) -> Result<(), String> {
        if self.connection.is_some() {
            return Ok(());
        }
        if !Self::is_installed() {
            self.state = HelperConnectionState::Missing;
            return Err("The privileged helper is not installed.".into());
        }
        self.state = HelperConnectionState::Checking;
        let stream = UnixStream::connect(SOCKET_PATH).map_err(|e| {
            self.state = HelperConnectionState::Unreachable;
            format!("Could not reach the fan helper: {e}")
        })?;
        let _ = stream.set_read_timeout(Some(Duration::from_secs(8)));
        let reader = BufReader::new(stream.try_clone().map_err(|e| e.to_string())?);
        self.connection = Some((stream, reader));
        Ok(())
    }

    pub fn request(&mut self, request: &Request) -> Result<Response, String> {
        #[cfg(unix)]
        {
            let result = self.ensure_connected().and_then(|_| {
                let (stream, reader) = self.connection.as_mut().unwrap();
                let mut line = serde_json::to_string(request).map_err(|e| e.to_string())?;
                line.push('\n');
                stream
                    .write_all(line.as_bytes())
                    .map_err(|e| e.to_string())?;
                let mut reply = String::new();
                if reader.read_line(&mut reply).map_err(|e| e.to_string())? == 0 {
                    return Err(
                        "The fan helper closed the connection (client not authorized?)".into(),
                    );
                }
                serde_json::from_str::<Response>(&reply).map_err(|e| e.to_string())
            });
            match &result {
                Ok(r) => {
                    self.state = HelperConnectionState::Reachable;
                    self.last_error = r.error.clone();
                }
                Err(e) => {
                    self.connection = None;
                    if self.state != HelperConnectionState::Missing {
                        self.state = HelperConnectionState::Unreachable;
                    }
                    self.last_error = Some(e.clone());
                }
            }
            result
        }
        #[cfg(not(unix))]
        {
            let _ = request;
            Err("The fan helper is only available on macOS.".into())
        }
    }

    /// Dropping the socket makes the helper restore automatic control at once.
    pub fn disconnect(&mut self) {
        #[cfg(unix)]
        {
            self.connection = None;
        }
    }
}
