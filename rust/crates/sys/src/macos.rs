//! Mach, sysctl, IOKit registry and libproc readers.
#![allow(deprecated)]
use crate::smc::{matching_service, IOObjectRelease};
use core_foundation::base::{CFType, TCFType};
use core_foundation::boolean::CFBoolean;
use core_foundation::dictionary::{CFDictionary, CFDictionaryRef, CFMutableDictionaryRef};
use core_foundation::number::CFNumber;
use core_foundation::string::CFString;
use core_monitor_core::network::NetworkCounter;
use core_monitor_core::snapshot::{self, BatteryInfo, DiskStats, ProcessActivity, ThermalState};
use std::collections::HashMap;
use std::ffi::{c_void, CString};

fn sysctl_by_name<T: Copy>(name: &str) -> Option<T> {
    let name = CString::new(name).ok()?;
    let mut value = std::mem::MaybeUninit::<T>::zeroed();
    let mut size = std::mem::size_of::<T>();
    let rc = unsafe {
        libc::sysctlbyname(
            name.as_ptr(),
            value.as_mut_ptr() as *mut c_void,
            &mut size,
            std::ptr::null_mut(),
            0,
        )
    };
    (rc == 0 && size == std::mem::size_of::<T>()).then(|| unsafe { value.assume_init() })
}

pub fn sysctl_string(name: &str) -> Option<String> {
    let cname = CString::new(name).ok()?;
    let mut size = 0usize;
    unsafe {
        libc::sysctlbyname(
            cname.as_ptr(),
            std::ptr::null_mut(),
            &mut size,
            std::ptr::null_mut(),
            0,
        )
    };
    let mut buf = vec![0u8; size];
    let rc = unsafe {
        libc::sysctlbyname(
            cname.as_ptr(),
            buf.as_mut_ptr() as *mut c_void,
            &mut size,
            std::ptr::null_mut(),
            0,
        )
    };
    if rc != 0 {
        return None;
    }
    buf.truncate(size);
    Some(
        String::from_utf8_lossy(&buf)
            .trim_end_matches('\0')
            .trim()
            .to_string(),
    )
}

pub fn is_apple_silicon() -> bool {
    sysctl_by_name::<i32>("hw.optional.arm64") == Some(1)
}

pub fn chip_name() -> String {
    sysctl_string("machdep.cpu.brand_string").unwrap_or_else(|| "Apple Silicon".into())
}

pub fn cpu_ticks() -> Option<[u32; 4]> {
    let mut info = libc::host_cpu_load_info { cpu_ticks: [0; 4] };
    let mut count = libc::HOST_CPU_LOAD_INFO_COUNT;
    let kr = unsafe {
        libc::host_statistics(
            libc::mach_host_self(),
            libc::HOST_CPU_LOAD_INFO,
            &mut info as *mut _ as *mut i32,
            &mut count,
        )
    };
    (kr == 0).then(|| {
        [
            info.cpu_ticks[0],
            info.cpu_ticks[1],
            info.cpu_ticks[2],
            info.cpu_ticks[3],
        ]
    })
}

pub struct Memory {
    pub stats: snapshot::MemoryStats,
    pub swap_used: u64,
    pub swap_total: u64,
}

pub fn memory() -> Option<Memory> {
    let mut vm: libc::vm_statistics64 = unsafe { std::mem::zeroed() };
    let mut count = libc::HOST_VM_INFO64_COUNT;
    let kr = unsafe {
        libc::host_statistics64(
            libc::mach_host_self(),
            libc::HOST_VM_INFO64,
            &mut vm as *mut _ as *mut i32,
            &mut count,
        )
    };
    if kr != 0 {
        return None;
    }
    let page_size = unsafe { libc::vm_page_size };
    let total: u64 = sysctl_by_name("hw.memsize")?;
    let stats = snapshot::memory_stats(
        vm.active_count as u64,
        vm.wire_count as u64,
        vm.compressor_page_count as u64,
        page_size as u64,
        total,
    )?;
    let swap: Option<libc::xsw_usage> = sysctl_by_name("vm.swapusage");
    Some(Memory {
        stats,
        swap_used: swap.map_or(0, |s| s.xsu_used),
        swap_total: swap.map_or(0, |s| s.xsu_total),
    })
}

pub fn disk() -> Option<DiskStats> {
    let path = CString::new("/").unwrap();
    let mut fs: libc::statfs = unsafe { std::mem::zeroed() };
    if unsafe { libc::statfs(path.as_ptr(), &mut fs) } != 0 {
        return None;
    }
    let block = fs.f_bsize as u64;
    Some(DiskStats::from_bytes(
        fs.f_blocks * block,
        fs.f_bavail * block,
        0,
    ))
}

/// NET_RT_IFLIST2 gives 64-bit counters; `getifaddrs` truncates to 32 bits.
pub fn network_counters() -> Option<HashMap<u16, NetworkCounter>> {
    let mut mib = [libc::CTL_NET, libc::PF_ROUTE, 0, 0, libc::NET_RT_IFLIST2, 0];
    for _ in 0..3 {
        let mut len = 0usize;
        if unsafe {
            libc::sysctl(
                mib.as_mut_ptr(),
                6,
                std::ptr::null_mut(),
                &mut len,
                std::ptr::null_mut(),
                0,
            )
        } != 0
        {
            return None;
        }
        let mut buf = vec![0u8; len];
        if unsafe {
            libc::sysctl(
                mib.as_mut_ptr(),
                6,
                buf.as_mut_ptr() as *mut c_void,
                &mut len,
                std::ptr::null_mut(),
                0,
            )
        } != 0
        {
            if std::io::Error::last_os_error().raw_os_error() == Some(libc::ENOMEM) {
                continue;
            }
            return None;
        }
        buf.truncate(len);
        return decode_iflist2(&buf);
    }
    None
}

fn decode_iflist2(buf: &[u8]) -> Option<HashMap<u16, NetworkCounter>> {
    let mut counters = HashMap::new();
    let mut offset = 0;
    while offset < buf.len() {
        if buf.len() - offset < 4 {
            return None;
        }
        let len = u16::from_ne_bytes([buf[offset], buf[offset + 1]]) as usize;
        if len < 4 || len > buf.len() - offset {
            return None;
        }
        if buf[offset + 3] as i32 == libc::RTM_IFINFO2 {
            if len < std::mem::size_of::<libc::if_msghdr2>() {
                return None;
            }
            let header: libc::if_msghdr2 =
                unsafe { std::ptr::read_unaligned(buf[offset..].as_ptr() as *const _) };
            if header.ifm_flags & libc::IFF_LOOPBACK == 0 {
                counters.insert(
                    header.ifm_index,
                    NetworkCounter {
                        sent: header.ifm_data.ifi_obytes,
                        received: header.ifm_data.ifi_ibytes,
                    },
                );
            }
        }
        offset += len;
    }
    Some(counters)
}

pub fn thermal_state() -> ThermalState {
    use objc2_foundation::{NSProcessInfo, NSProcessInfoThermalState};
    match NSProcessInfo::processInfo().thermalState() {
        NSProcessInfoThermalState::Fair => ThermalState::Fair,
        NSProcessInfoThermalState::Serious => ThermalState::Serious,
        NSProcessInfoThermalState::Critical => ThermalState::Critical,
        _ => ThermalState::Nominal,
    }
}

#[link(name = "IOKit", kind = "framework")]
extern "C" {
    fn IORegistryEntryCreateCFProperties(
        entry: u32,
        props: *mut CFMutableDictionaryRef,
        alloc: *const c_void,
        options: u32,
    ) -> i32;
    fn IOPSCopyPowerSourcesInfo() -> *const c_void;
    fn IOPSCopyPowerSourcesList(blob: *const c_void) -> *const c_void;
    fn IOPSGetPowerSourceDescription(blob: *const c_void, ps: *const c_void) -> CFDictionaryRef;
}

struct Props(CFDictionary<CFString, CFType>);

impl Props {
    fn int(&self, key: &str) -> Option<i64> {
        self.0
            .find(CFString::new(key))
            .and_then(|v| v.downcast::<CFNumber>())
            .and_then(|n| n.to_i64())
    }
    fn bool(&self, key: &str) -> Option<bool> {
        self.0
            .find(CFString::new(key))
            .and_then(|v| v.downcast::<CFBoolean>())
            .map(bool::from)
    }
    fn string(&self, key: &str) -> Option<String> {
        self.0
            .find(CFString::new(key))
            .and_then(|v| v.downcast::<CFString>())
            .map(|s| s.to_string())
    }
}

fn power_source() -> Option<Props> {
    unsafe {
        let blob = IOPSCopyPowerSourcesInfo();
        if blob.is_null() {
            return None;
        }
        let blob = CFType::wrap_under_create_rule(blob);
        let list = IOPSCopyPowerSourcesList(blob.as_CFTypeRef());
        if list.is_null() {
            return None;
        }
        let list: core_foundation::array::CFArray<CFType> =
            core_foundation::array::CFArray::wrap_under_create_rule(list as _);
        let first = list.get(0)?;
        let desc = IOPSGetPowerSourceDescription(blob.as_CFTypeRef(), first.as_CFTypeRef());
        (!desc.is_null()).then(|| Props(CFDictionary::wrap_under_get_rule(desc as _)))
    }
}

pub fn battery() -> BatteryInfo {
    let mut info = BatteryInfo::default();
    if let Some(ps) = power_source() {
        info.has_battery = ps.string("Type").as_deref() == Some("InternalBattery");
        if let (Some(cur), Some(max)) = (ps.int("Current Capacity"), ps.int("Max Capacity")) {
            if max > 0 {
                info.charge_percent = Some((cur as f64 / max as f64 * 100.0).round() as i64);
            }
        }
        info.is_charging = ps.bool("Is Charging").unwrap_or(false);
        info.source = ps.string("Power Source State");
        info.is_plugged_in = info.source.as_deref() == Some("AC Power");
        info.time_remaining_minutes = core_monitor_core::format::time_remaining_minutes(
            info.is_charging,
            info.is_plugged_in,
            ps.int("Time to Empty"),
            ps.int("Time to Full Charge"),
        );
    }
    let Some(service) = matching_service("AppleSmartBattery") else {
        return info;
    };
    let mut props: CFMutableDictionaryRef = std::ptr::null_mut();
    let kr = unsafe { IORegistryEntryCreateCFProperties(service, &mut props, std::ptr::null(), 0) };
    unsafe { IOObjectRelease(service) };
    if kr != 0 || props.is_null() {
        return info;
    }
    let p = Props(unsafe { CFDictionary::wrap_under_create_rule(props as CFDictionaryRef) });
    info.has_battery = true;
    info.cycle_count = p.int("CycleCount");
    info.current_capacity = p
        .int("AppleRawCurrentCapacity")
        .or(p.int("CurrentCapacity"));
    info.max_capacity = p.int("AppleRawMaxCapacity").or(p.int("MaxCapacity"));
    let design = p.int("DesignCapacity").or(p.int("NominalChargeCapacity"));
    if let (Some(max), Some(design)) = (info.max_capacity, design) {
        info.health_percent = snapshot::battery_health_percent(max, design);
    }
    info.temperature_c = p
        .int("Temperature")
        .and_then(snapshot::battery_temperature_c);
    info.voltage_v = p.int("Voltage").map(|mv| mv as f64 / 1000.0);
    info.amperage_a = p.int("Amperage").map(|ma| ma as f64 / 1000.0);
    if let (Some(v), Some(a)) = (info.voltage_v, info.amperage_a) {
        info.power_watts = Some(v * a);
    }
    info
}

/// Per-process cumulative CPU time (ns) and resident memory.
pub fn processes() -> Vec<(i32, String, u64, u64)> {
    let mut pids = vec![0i32; 4096];
    let n = unsafe {
        libc::proc_listallpids(pids.as_mut_ptr() as *mut c_void, (pids.len() * 4) as i32)
    };
    if n <= 0 {
        return Vec::new();
    }
    pids.truncate(n as usize);
    let mut out = Vec::with_capacity(pids.len());
    for pid in pids.into_iter().filter(|p| *p > 0) {
        let mut task: libc::proc_taskinfo = unsafe { std::mem::zeroed() };
        let size = std::mem::size_of::<libc::proc_taskinfo>() as i32;
        if unsafe {
            libc::proc_pidinfo(
                pid,
                libc::PROC_PIDTASKINFO,
                0,
                &mut task as *mut _ as *mut c_void,
                size,
            )
        } != size
        {
            continue;
        }
        let mut name = [0u8; 256];
        let len =
            unsafe { libc::proc_name(pid, name.as_mut_ptr() as *mut c_void, name.len() as u32) };
        let name = if len > 0 {
            String::from_utf8_lossy(&name[..len as usize]).into_owned()
        } else {
            format!("pid {pid}")
        };
        out.push((
            pid,
            name,
            task.pti_total_user + task.pti_total_system,
            task.pti_resident_size,
        ));
    }
    out
}

/// Mach absolute time units to nanoseconds.
pub fn timebase_ratio() -> f64 {
    let mut tb = libc::mach_timebase_info { numer: 0, denom: 0 };
    unsafe { libc::mach_timebase_info(&mut tb) };
    if tb.denom == 0 {
        1.0
    } else {
        tb.numer as f64 / tb.denom as f64
    }
}

pub fn top(
    processes: &[(i32, String, u64, u64)],
    cpu: &HashMap<i32, f64>,
    limit: usize,
) -> (Vec<ProcessActivity>, Vec<ProcessActivity>) {
    let mut all: Vec<ProcessActivity> = processes
        .iter()
        .map(|(pid, name, _, mem)| ProcessActivity {
            pid: *pid,
            name: name.clone(),
            cpu_percent: cpu.get(pid).copied().unwrap_or(0.0),
            memory_bytes: *mem,
        })
        .collect();
    all.sort_by(|a, b| b.cpu_percent.total_cmp(&a.cpu_percent));
    let top_cpu = all.iter().take(limit).cloned().collect();
    all.sort_by_key(|a| std::cmp::Reverse(a.memory_bytes));
    (top_cpu, all.into_iter().take(limit).collect())
}
