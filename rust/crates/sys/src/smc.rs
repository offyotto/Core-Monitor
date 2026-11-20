//! AppleSMC user client.
use crate::{Error, Result};
use core_monitor_core::smc::{self as codec, SmcKeyInfo, SmcParam};
use std::ffi::{c_char, c_void, CString};
use std::sync::Mutex;

pub type IoObject = u32;
type KernReturn = i32;

#[link(name = "IOKit", kind = "framework")]
extern "C" {
    fn IOServiceMatching(name: *const c_char) -> *mut c_void;
    fn IOServiceGetMatchingService(main_port: u32, matching: *mut c_void) -> IoObject;
    fn IOServiceOpen(
        service: IoObject,
        owning_task: u32,
        kind: u32,
        connect: *mut IoObject,
    ) -> KernReturn;
    fn IOServiceClose(connect: IoObject) -> KernReturn;
    pub(crate) fn IOObjectRelease(object: IoObject) -> KernReturn;
    fn IOConnectCallStructMethod(
        connection: IoObject,
        selector: u32,
        input: *const c_void,
        input_size: usize,
        output: *mut c_void,
        output_size: *mut usize,
    ) -> KernReturn;
}

pub(crate) fn matching_service(name: &str) -> Option<IoObject> {
    let name = CString::new(name).ok()?;
    let service = unsafe { IOServiceGetMatchingService(0, IOServiceMatching(name.as_ptr())) };
    (service != 0).then_some(service)
}

/// An open connection to the AppleSMC kernel extension.
pub struct Smc {
    connection: IoObject,
    key_info_cache: Mutex<std::collections::HashMap<u32, SmcKeyInfo>>,
}

// The connection handle is a Mach port name usable from any thread.
unsafe impl Send for Smc {}
unsafe impl Sync for Smc {}

impl Smc {
    pub fn open() -> Result<Self> {
        let service = matching_service("AppleSMC")
            .ok_or_else(|| Error("AppleSMC service not found".into()))?;
        let mut connection = 0;
        #[allow(deprecated)]
        let task = unsafe { libc::mach_task_self() };
        let kr = unsafe { IOServiceOpen(service, task, 0, &mut connection) };
        unsafe { IOObjectRelease(service) };
        if kr != 0 {
            return Err(Error(format!("IOServiceOpen(AppleSMC) failed: {kr:#x}")));
        }
        Ok(Self {
            connection,
            key_info_cache: Mutex::new(Default::default()),
        })
    }

    fn call(&self, input: &SmcParam) -> Result<SmcParam> {
        let mut output = SmcParam::default();
        let mut size = std::mem::size_of::<SmcParam>();
        let kr = unsafe {
            IOConnectCallStructMethod(
                self.connection,
                codec::KERNEL_INDEX_SMC,
                input as *const _ as *const c_void,
                std::mem::size_of::<SmcParam>(),
                &mut output as *mut _ as *mut c_void,
                &mut size,
            )
        };
        if kr != 0 {
            return Err(Error(format!("SMC call failed: {kr:#x}")));
        }
        if output.result != 0 {
            return Err(Error(format!("SMC returned result {}", output.result)));
        }
        Ok(output)
    }

    pub fn key_info(&self, key: &str) -> Result<SmcKeyInfo> {
        codec::validate_key(key).map_err(Error)?;
        let code = codec::four_cc_str(key);
        if let Some(info) = self.key_info_cache.lock().unwrap().get(&code) {
            return Ok(*info);
        }
        let input = SmcParam {
            key: code,
            data8: codec::CMD_READ_KEY_INFO,
            ..Default::default()
        };
        let info = self.call(&input)?.key_info;
        self.key_info_cache.lock().unwrap().insert(code, info);
        Ok(info)
    }

    pub fn read_raw(&self, key: &str) -> Result<(SmcKeyInfo, [u8; 32])> {
        let info = self.key_info(key)?;
        let input = SmcParam {
            key: codec::four_cc_str(key),
            key_info: info,
            data8: codec::CMD_READ_BYTES,
            ..Default::default()
        };
        Ok((info, self.call(&input)?.bytes))
    }

    pub fn read(&self, key: &str) -> Option<f64> {
        let (info, raw) = self.read_raw(key).ok()?;
        codec::decode(&raw, Some(key), info.data_type, info.data_size)
    }

    pub fn read_strict(&self, key: &str) -> Option<f64> {
        let (info, raw) = self.read_raw(key).ok()?;
        codec::decode_strict(&raw, Some(key), info.data_type, info.data_size)
    }

    pub fn key_exists(&self, key: &str) -> bool {
        self.key_info(key).is_ok_and(|i| i.data_size > 0)
    }

    pub fn write(&self, key: &str, value: i64) -> Result<()> {
        let info = self.key_info(key)?;
        let bytes = codec::encode(value, info.data_type, info.data_size).map_err(Error)?;
        let input = SmcParam {
            key: codec::four_cc_str(key),
            key_info: info,
            data8: codec::CMD_WRITE_BYTES,
            bytes,
            ..Default::default()
        };
        self.call(&input).map(|_| ())
    }

    pub fn fan_count(&self) -> usize {
        core_monitor_core::fan_detection::validated_count(self.read("FNum")).unwrap_or_else(|| {
            core_monitor_core::fan_detection::fallback_count(|k| self.key_exists(k))
        })
    }
}

impl Drop for Smc {
    fn drop(&mut self) {
        unsafe { IOServiceClose(self.connection) };
    }
}
