//! Unix-socket service. Every connection is checked against a code signing
//! requirement via its audit token, owns the fans it writes through a lease,
//! and loses them the moment it disconnects or stops renewing.
use crate::fans::Fans;
use core_foundation::base::{CFType, CFTypeRef, TCFType};
use core_foundation::data::CFData;
use core_foundation::dictionary::CFDictionary;
use core_foundation::string::{CFString, CFStringRef};
use core_monitor_core::helper_protocol::{self as p, Request, Response};
use core_monitor_core::lease::FanControlLease;
use std::ffi::c_void;
use std::io::{BufRead, BufReader, Write};
use std::os::fd::AsRawFd;
use std::os::unix::net::{UnixListener, UnixStream};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

#[link(name = "Security", kind = "framework")]
extern "C" {
    static kSecGuestAttributeAudit: CFStringRef;
    fn SecRequirementCreateWithString(text: CFStringRef, flags: u32, req: *mut CFTypeRef) -> i32;
    fn SecCodeCopyGuestWithAttributes(
        host: CFTypeRef,
        attrs: CFTypeRef,
        flags: u32,
        guest: *mut CFTypeRef,
    ) -> i32;
    fn SecCodeCheckValidity(code: CFTypeRef, flags: u32, req: CFTypeRef) -> i32;
}

const SOL_LOCAL: i32 = 0;
const LOCAL_PEERTOKEN: i32 = 6;

struct Requirement(CFType);
unsafe impl Send for Requirement {}
unsafe impl Sync for Requirement {}

impl Requirement {
    fn new(text: &str) -> Result<Self, String> {
        if text.trim().is_empty() {
            return Err("A client code signing requirement is required".into());
        }
        let mut req: CFTypeRef = std::ptr::null();
        let status = unsafe {
            SecRequirementCreateWithString(CFString::new(text).as_concrete_TypeRef(), 0, &mut req)
        };
        if status != 0 || req.is_null() {
            return Err(format!("Invalid client requirement ({status})"));
        }
        Ok(Self(unsafe { CFType::wrap_under_create_rule(req) }))
    }

    fn accepts(&self, stream: &UnixStream) -> bool {
        let mut token = [0u8; 32];
        let mut len = token.len() as libc::socklen_t;
        let rc = unsafe {
            libc::getsockopt(
                stream.as_raw_fd(),
                SOL_LOCAL,
                LOCAL_PEERTOKEN,
                token.as_mut_ptr() as *mut c_void,
                &mut len,
            )
        };
        if rc != 0 || len as usize != token.len() {
            return false;
        }
        let key = unsafe { CFString::wrap_under_get_rule(kSecGuestAttributeAudit) };
        let attrs = CFDictionary::from_CFType_pairs(&[(
            key.as_CFType(),
            CFData::from_buffer(&token).as_CFType(),
        )]);
        let mut code: CFTypeRef = std::ptr::null();
        if unsafe {
            SecCodeCopyGuestWithAttributes(std::ptr::null(), attrs.as_CFTypeRef(), 0, &mut code)
        } != 0
            || code.is_null()
        {
            return false;
        }
        let code = unsafe { CFType::wrap_under_create_rule(code) };
        unsafe { SecCodeCheckValidity(code.as_CFTypeRef(), 0, self.0.as_CFTypeRef()) == 0 }
    }
}

struct State {
    fans: Fans,
    lease: FanControlLease,
}

fn clock(start: Instant) -> f64 {
    start.elapsed().as_secs_f64()
}

fn handle(state: &Mutex<State>, owner: u64, start: Instant, request: Request) -> Response {
    let mut s = state.lock().unwrap();
    let now = clock(start);
    let result = match request {
        Request::Read { key } => core_monitor_core::smc::validate_key(&key)
            .map(str::to_owned)
            .and_then(|k| s.fans.read(&k))
            .map(Response::value),
        Request::Renew => Ok(Response::value(if s.lease.renewed(owner, now) {
            1.0
        } else {
            0.0
        })),
        Request::Metadata => {
            let template = s.fans.mode_key_template().to_string();
            let force = s.fans.has_force_test();
            Ok(Response {
                ok: true,
                mode_key_template: Some(template),
                has_force_test_key: Some(force),
                ..Default::default()
            })
        }
        Request::SetManual { fan, rpm } => p::validate_fan_id(fan).and_then(|fan| {
            let rpm = p::validate_requested_rpm(rpm)?;
            // Ownership is recorded before the write so a partial write is still recovered.
            if !s.lease.acquire(fan, owner, now) {
                return Err(format!("Fan {fan} is controlled by another client"));
            }
            s.fans.set_manual(fan, rpm).map(|_| Response::ok()).inspect_err(|_| {
                // A partial write may have left the fan in manual mode; hand it
                // back now instead of waiting for a lease the client keeps renewing.
                if s.fans.set_auto(fan).is_ok() {
                    s.lease.release(fan);
                }
            })
        }),
        Request::SetAuto { fan } => p::validate_fan_id(fan).and_then(|fan| {
            if !s.lease.can_control(fan, owner) {
                return Err(format!("Fan {fan} is controlled by another client"));
            }
            s.fans.set_auto(fan)?;
            s.lease.release(fan);
            Ok(Response::ok())
        }),
    };
    result.unwrap_or_else(Response::error)
}

fn session(stream: UnixStream, state: Arc<Mutex<State>>, owner: u64, start: Instant) {
    let mut writer = match stream.try_clone() {
        Ok(w) => w,
        Err(_) => return,
    };
    for line in BufReader::new(stream).lines() {
        let Ok(line) = line else { break };
        let response = match serde_json::from_str::<Request>(&line) {
            Ok(request) => handle(&state, owner, start, request),
            Err(e) => Response::error(format!("Malformed request: {e}")),
        };
        let mut out = serde_json::to_string(&response).unwrap();
        out.push('\n');
        if writer.write_all(out.as_bytes()).is_err() {
            break;
        }
    }
    let mut s = state.lock().unwrap();
    s.lease.expire(owner);
    let now = clock(start);
    let State { fans, lease } = &mut *s;
    lease.restore_expired(now, |fan| fans.set_auto(fan));
}

pub fn serve(path: &str, requirement: &str) -> Result<(), String> {
    let requirement = Arc::new(Requirement::new(requirement)?);
    let state = Arc::new(Mutex::new(State {
        fans: Fans::open()?,
        lease: FanControlLease::default(),
    }));
    let start = Instant::now();
    let _ = std::fs::remove_file(path);
    let listener = UnixListener::bind(path).map_err(|e| format!("bind {path}: {e}"))?;
    // Any local user may connect; the code signing check below is the gate.
    std::fs::set_permissions(path, std::os::unix::fs::PermissionsExt::from_mode(0o666))
        .map_err(|e| e.to_string())?;

    let watchdog = state.clone();
    std::thread::spawn(move || loop {
        std::thread::sleep(Duration::from_secs(1));
        let mut s = watchdog.lock().unwrap();
        let State { fans, lease } = &mut *s;
        let failed = lease.restore_expired(clock(start), |fan| fans.set_auto(fan));
        for fan in failed {
            eprintln!("smc-helper: restoring automatic control on fan {fan} failed; will retry");
        }
    });

    let next_owner = AtomicU64::new(1);
    for stream in listener.incoming() {
        let Ok(stream) = stream else { continue };
        if !requirement.accepts(&stream) {
            eprintln!("smc-helper: rejected client that failed the code signing requirement");
            continue;
        }
        let owner = next_owner.fetch_add(1, Ordering::Relaxed);
        let state = state.clone();
        std::thread::spawn(move || session(stream, state, owner, start));
    }
    Ok(())
}
