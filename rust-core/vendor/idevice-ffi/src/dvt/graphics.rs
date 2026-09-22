// Jackson Coxson

use std::{ffi::CString, ptr::null_mut};

use idevice::{ReadWrite, dvt::graphics::GraphicsClient};

use crate::{IdeviceFfiError, dvt::remote_server::RemoteServerHandle, ffi_err, run_sync};

pub struct GraphicsHandle<'a>(pub GraphicsClient<'a, Box<dyn ReadWrite>>);

/// A graphics sample from tddhe GPU instruments channel
#[repr(C)]
pub struct IdeviceGraphicsSample {
    pub timestamp: u64,
    pub fps: f64,
    pub alloc_system_memory: u64,
    pub in_use_system_memory: u64,
    pub in_use_system_memory_driver: u64,
    pub gpu_bundle_name: *mut std::ffi::c_char,
    pub recovery_count: u64,
}

/// Frees an IdeviceGraphicsSample and its heap-allocated string field
///
/// # Safety
/// `sample` must be a valid pointer allocated by this library or NULL
#[unsafe(no_mangle)]
pub unsafe extern "C" fn graphics_sample_free(sample: *mut IdeviceGraphicsSample) {
    if sample.is_null() {
        return;
    }
    let s = unsafe { Box::from_raw(sample) };
    if !s.gpu_bundle_name.is_null() {
        let _ = unsafe { CString::from_raw(s.gpu_bundle_name) };
    }
}

/// Creates a new GraphicsClient from a RemoteServerClient
///
/// # Safety
/// `server` must be a valid pointer to a handle allocated by this library
/// `handle` must be a valid pointer to a location where the handle will be stored
#[unsafe(no_mangle)]
pub unsafe extern "C" fn graphics_new(
    server: *mut RemoteServerHandle,
    handle: *mut *mut GraphicsHandle<'static>,
) -> *mut IdeviceFfiError {
    if server.is_null() || handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let server = unsafe { &mut (*server).0 };
    let res = run_sync(async move { GraphicsClient::new(server).await });

    match res {
        Ok(client) => {
            let boxed = Box::new(GraphicsHandle(client));
            unsafe { *handle = Box::into_raw(boxed) };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Frees a GraphicsClient handle
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library or NULL
#[unsafe(no_mangle)]
pub unsafe extern "C" fn graphics_free(handle: *mut GraphicsHandle<'static>) {
    if !handle.is_null() {
        let _ = unsafe { Box::from_raw(handle) };
    }
}

/// Starts graphics sampling at the given interval. Consumes the device's initial reply internally.
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library
#[unsafe(no_mangle)]
pub unsafe extern "C" fn graphics_start_sampling(
    handle: *mut GraphicsHandle<'static>,
    interval: f64,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let client = unsafe { &mut (*handle).0 };
    let res = run_sync(async move { client.start_sampling(interval).await });

    match res {
        Ok(_) => null_mut(),
        Err(e) => ffi_err!(e),
    }
}

/// Stops graphics sampling.
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library
#[unsafe(no_mangle)]
pub unsafe extern "C" fn graphics_stop_sampling(
    handle: *mut GraphicsHandle<'static>,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let client = unsafe { &mut (*handle).0 };
    let res = run_sync(async move { client.stop_sampling().await });

    match res {
        Ok(_) => null_mut(),
        Err(e) => ffi_err!(e),
    }
}

/// Reads the next graphics data frame pushed by the device. Blocks until a frame arrives.
///
/// # Arguments
/// * [`handle`] - The GraphicsClient handle
/// * [`sample_out`] - On success, set to a heap-allocated IdeviceGraphicsSample
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All pointers must be valid and non-null. Free the sample with `graphics_sample_free`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn graphics_next_sample(
    handle: *mut GraphicsHandle<'static>,
    sample_out: *mut *mut IdeviceGraphicsSample,
) -> *mut IdeviceFfiError {
    if handle.is_null() || sample_out.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let client = unsafe { &mut (*handle).0 };
    let res = run_sync(async move { client.sample().await });

    match res {
        Ok(sample) => {
            let c_sample = IdeviceGraphicsSample {
                timestamp: sample.timestamp,
                fps: sample.fps,
                alloc_system_memory: sample.alloc_system_memory,
                in_use_system_memory: sample.in_use_system_memory,
                in_use_system_memory_driver: sample.in_use_system_memory_driver,
                gpu_bundle_name: CString::new(sample.gpu_bundle_name)
                    .unwrap_or_default()
                    .into_raw(),
                recovery_count: sample.recovery_count,
            };
            unsafe { *sample_out = Box::into_raw(Box::new(c_sample)) };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}
