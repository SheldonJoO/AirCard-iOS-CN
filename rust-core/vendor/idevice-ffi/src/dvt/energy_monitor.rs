// Jackson Coxson

use std::ptr::null_mut;

use idevice::{
    ReadWrite,
    dvt::energy_monitor::{EnergyMonitorClient, EnergySample},
};

use crate::{IdeviceFfiError, dvt::remote_server::RemoteServerHandle, ffi_err, run_sync};

pub struct EnergyMonitorHandle<'a>(pub EnergyMonitorClient<'a, Box<dyn ReadWrite>>);

/// A parsed per-PID energy sample
#[repr(C)]
pub struct IdeviceEnergySample {
    pub pid: u32,
    pub timestamp: i64,
    pub total_energy: f64,
    pub cpu_energy: f64,
    pub gpu_energy: f64,
    pub networking_energy: f64,
    pub display_energy: f64,
    pub location_energy: f64,
    pub appstate_energy: f64,
}

/// Creates a new EnergyMonitorClient from a RemoteServerClient
///
/// # Safety
/// `server` must be a valid pointer to a handle allocated by this library
/// `handle` must be a valid pointer to a location where the handle will be stored
#[unsafe(no_mangle)]
pub unsafe extern "C" fn energy_monitor_new(
    server: *mut RemoteServerHandle,
    handle: *mut *mut EnergyMonitorHandle<'static>,
) -> *mut IdeviceFfiError {
    if server.is_null() || handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let server = unsafe { &mut (*server).0 };
    let res = run_sync(async move { EnergyMonitorClient::new(server).await });

    match res {
        Ok(client) => {
            let boxed = Box::new(EnergyMonitorHandle(client));
            unsafe { *handle = Box::into_raw(boxed) };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Frees an EnergyMonitorClient handle
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library or NULL
#[unsafe(no_mangle)]
pub unsafe extern "C" fn energy_monitor_free(handle: *mut EnergyMonitorHandle<'static>) {
    if !handle.is_null() {
        let _ = unsafe { Box::from_raw(handle) };
    }
}

/// Starts energy sampling for the given PIDs.
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library.
/// If `pids` is non-null it must point to at least `pids_count` readable `u32` values.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn energy_monitor_start_sampling(
    handle: *mut EnergyMonitorHandle<'static>,
    pids: *const u32,
    pids_count: usize,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let pids_vec: Vec<u32> = if pids.is_null() || pids_count == 0 {
        Vec::new()
    } else {
        unsafe { std::slice::from_raw_parts(pids, pids_count) }.to_vec()
    };

    let client = unsafe { &mut (*handle).0 };
    let res = run_sync(async move { client.start_sampling(&pids_vec).await });

    match res {
        Ok(_) => null_mut(),
        Err(e) => ffi_err!(e),
    }
}

/// Stops energy sampling for the given PIDs.
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library.
/// If `pids` is non-null it must point to at least `pids_count` readable `u32` values.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn energy_monitor_stop_sampling(
    handle: *mut EnergyMonitorHandle<'static>,
    pids: *const u32,
    pids_count: usize,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let pids_vec: Vec<u32> = if pids.is_null() || pids_count == 0 {
        Vec::new()
    } else {
        unsafe { std::slice::from_raw_parts(pids, pids_count) }.to_vec()
    };

    let client = unsafe { &mut (*handle).0 };
    let res = run_sync(async move { client.stop_sampling(&pids_vec).await });

    match res {
        Ok(_) => null_mut(),
        Err(e) => ffi_err!(e),
    }
}

/// Requests a one-shot energy sample and parses the response.
///
/// # Arguments
/// * [`handle`] - The EnergyMonitorClient handle
/// * [`pids`] - Pointer to an array of u32 PIDs to sample
/// * [`pids_count`] - Number of elements in `pids`
/// * [`samples_out`] - On success, set to a heap-allocated array of IdeviceEnergySample
/// * [`samples_count_out`] - On success, set to the number of samples
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All output pointers must be valid and non-null. Free the array with
/// `energy_monitor_samples_free`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn energy_monitor_sample_attributes(
    handle: *mut EnergyMonitorHandle<'static>,
    pids: *const u32,
    pids_count: usize,
    samples_out: *mut *mut IdeviceEnergySample,
    samples_count_out: *mut usize,
) -> *mut IdeviceFfiError {
    if handle.is_null() || samples_out.is_null() || samples_count_out.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let pids_vec: Vec<u32> = if pids.is_null() || pids_count == 0 {
        Vec::new()
    } else {
        unsafe { std::slice::from_raw_parts(pids, pids_count) }.to_vec()
    };

    let client = unsafe { &mut (*handle).0 };
    let bytes = match run_sync(async move { client.sample_attributes(&pids_vec).await }) {
        Ok(b) => b,
        Err(e) => return ffi_err!(e),
    };

    let samples = match EnergySample::from_bytes(&bytes) {
        Ok(v) => v,
        Err(e) => return ffi_err!(e),
    };

    let mut c_samples: Box<[IdeviceEnergySample]> = samples
        .into_iter()
        .map(|s| IdeviceEnergySample {
            pid: s.pid,
            timestamp: s.timestamp,
            total_energy: s.total_energy,
            cpu_energy: s.cpu_energy,
            gpu_energy: s.gpu_energy,
            networking_energy: s.networking_energy,
            display_energy: s.display_energy,
            location_energy: s.location_energy,
            appstate_energy: s.appstate_energy,
        })
        .collect::<Vec<_>>()
        .into_boxed_slice();

    unsafe {
        *samples_out = c_samples.as_mut_ptr();
        *samples_count_out = c_samples.len();
    }
    std::mem::forget(c_samples);
    null_mut()
}

/// Frees an array of IdeviceEnergySample allocated by `energy_monitor_sample_attributes`.
///
/// # Safety
/// `samples` must be a pointer returned by this library with the matching `count`, or NULL
#[unsafe(no_mangle)]
pub unsafe extern "C" fn energy_monitor_samples_free(
    samples: *mut IdeviceEnergySample,
    count: usize,
) {
    if samples.is_null() {
        return;
    }
    let _ = unsafe { Box::from_raw(std::ptr::slice_from_raw_parts_mut(samples, count)) };
}
