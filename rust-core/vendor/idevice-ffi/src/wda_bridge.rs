// Jackson Coxson

use std::{
    ffi::{CString, c_char},
    ptr::null_mut,
    sync::Arc,
};

use idevice::{
    provider::IdeviceProvider,
    services::{
        wda::WdaPorts,
        wda_bridge::{WdaBridge, WdaBridgeEndpoints},
    },
};

use crate::{IdeviceFfiError, ffi_err, provider::IdeviceProviderHandle, run_sync};

/// Opaque handle wrapping a [`WdaBridge`].
pub struct WdaBridgeHandle(pub WdaBridge);

/// Localhost endpoints exposed by a running WDA bridge.
///
/// Pointers in this struct are heap-allocated and must be released with
/// `wda_bridge_endpoints_free`.
#[repr(C)]
pub struct WdaBridgeEndpointsC {
    pub udid: *mut c_char,
    pub wda_url: *mut c_char,
    pub mjpeg_url: *mut c_char,
    pub local_http: u16,
    pub local_mjpeg: u16,
    pub device_http: u16,
    pub device_mjpeg: u16,
}

/// Starts a localhost bridge to the device's default WDA ports.
///
/// # Arguments
/// * [`provider`] - An IdeviceProvider. Provider ownership is transferred —
///   the caller must not free or reuse the IdeviceProviderHandle on success or failure.
/// * [`handle`] - On success, set to a newly allocated WdaBridgeHandle.
///
/// # Returns
/// An IdeviceFfiError on error, null on success.
///
/// # Safety
/// `provider` must be a valid pointer to a handle allocated by this library.
/// The provider is consumed, and may not be used again.
/// `handle` must be a valid, non-null pointer to a location where the handle will be stored.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_bridge_start(
    provider: *mut IdeviceProviderHandle,
    handle: *mut *mut WdaBridgeHandle,
) -> *mut IdeviceFfiError {
    if provider.is_null() || handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let provider_box = unsafe { Box::from_raw(provider) }.0;
    let arc: Arc<dyn IdeviceProvider> = Arc::from(provider_box);
    let res = run_sync(async move { WdaBridge::start(arc).await });
    match res {
        Ok(bridge) => {
            let boxed = Box::new(WdaBridgeHandle(bridge));
            unsafe { *handle = Box::into_raw(boxed) };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Starts a localhost bridge to custom device-side WDA ports.
///
/// # Safety
/// Same requirements as [`wda_bridge_start`].
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_bridge_start_with_ports(
    provider: *mut IdeviceProviderHandle,
    device_http: u16,
    device_mjpeg: u16,
    handle: *mut *mut WdaBridgeHandle,
) -> *mut IdeviceFfiError {
    if provider.is_null() || handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let provider_box = unsafe { Box::from_raw(provider) }.0;
    let arc: Arc<dyn IdeviceProvider> = Arc::from(provider_box);
    let ports = WdaPorts {
        http: device_http,
        mjpeg: device_mjpeg,
    };
    let res = run_sync(async move { WdaBridge::start_with_ports(arc, ports).await });
    match res {
        Ok(bridge) => {
            let boxed = Box::new(WdaBridgeHandle(bridge));
            unsafe { *handle = Box::into_raw(boxed) };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Reads the endpoints assigned to the running bridge.
///
/// # Arguments
/// * [`handle`] - The bridge handle.
/// * [`out_endpoints`] - On success, set to a heap-allocated WdaBridgeEndpointsC.
///   Free with `wda_bridge_endpoints_free`.
///
/// # Returns
/// An IdeviceFfiError on error, null on success.
///
/// # Safety
/// All pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_bridge_endpoints(
    handle: *mut WdaBridgeHandle,
    out_endpoints: *mut *mut WdaBridgeEndpointsC,
) -> *mut IdeviceFfiError {
    if handle.is_null() || out_endpoints.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let bridge = unsafe { &(*handle).0 };
    let endpoints = bridge.endpoints();
    let c_endpoints = endpoints_to_c(endpoints);
    unsafe { *out_endpoints = Box::into_raw(Box::new(c_endpoints)) };
    null_mut()
}

/// Frees a WdaBridgeEndpointsC struct and its heap-allocated string fields.
///
/// # Safety
/// `endpoints` must be a pointer returned by `wda_bridge_endpoints` or NULL.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_bridge_endpoints_free(endpoints: *mut WdaBridgeEndpointsC) {
    if endpoints.is_null() {
        return;
    }
    let e = unsafe { Box::from_raw(endpoints) };
    if !e.udid.is_null() {
        let _ = unsafe { CString::from_raw(e.udid) };
    }
    if !e.wda_url.is_null() {
        let _ = unsafe { CString::from_raw(e.wda_url) };
    }
    if !e.mjpeg_url.is_null() {
        let _ = unsafe { CString::from_raw(e.mjpeg_url) };
    }
}

/// Frees a WDA bridge handle. Dropping aborts the underlying forwarder tasks.
///
/// # Safety
/// `handle` must be a pointer returned by this library or NULL.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_bridge_free(handle: *mut WdaBridgeHandle) {
    if !handle.is_null() {
        let _ = unsafe { Box::from_raw(handle) };
    }
}

fn endpoints_to_c(e: &WdaBridgeEndpoints) -> WdaBridgeEndpointsC {
    let udid = match &e.udid {
        Some(s) => CString::new(s.as_str()).unwrap_or_default().into_raw(),
        None => null_mut(),
    };
    WdaBridgeEndpointsC {
        udid,
        wda_url: CString::new(e.wda_url.as_str())
            .unwrap_or_default()
            .into_raw(),
        mjpeg_url: CString::new(e.mjpeg_url.as_str())
            .unwrap_or_default()
            .into_raw(),
        local_http: e.local_ports.http,
        local_mjpeg: e.local_ports.mjpeg,
        device_http: e.device_ports.http,
        device_mjpeg: e.device_ports.mjpeg,
    }
}
