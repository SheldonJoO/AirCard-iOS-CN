// Jackson Coxson

use std::{
    ffi::{CStr, CString, c_char},
    ptr::null_mut,
    time::Duration,
};

use idevice::{
    IdeviceError,
    provider::IdeviceProvider,
    services::wda::{DEFAULT_WDA_MJPEG_PORT, DEFAULT_WDA_PORT, WdaClient, WdaPorts},
};
use serde_json::{Map, Value};

use crate::{IdeviceFfiError, ffi_err, provider::IdeviceProviderHandle, run_sync_local};

const DEFAULT_WDA_TIMEOUT: Duration = Duration::from_secs(10);

/// Opaque handle wrapping the WDA client state.
///
/// The handle owns the provider so that subsequent calls can open fresh
/// per-request connections without the caller juggling a separate
/// `IdeviceProviderHandle`.
pub struct WdaClientHandle {
    provider: Box<dyn IdeviceProvider>,
    ports: WdaPorts,
    timeout: Duration,
    session_id: Option<String>,
}

impl WdaClientHandle {
    fn build_client(&self) -> WdaClient<'_> {
        WdaClient::new(&*self.provider)
            .with_ports(self.ports)
            .with_timeout(self.timeout)
    }
}

/// Creates a new WDA client bound to the given provider.
///
/// # Arguments
/// * [`provider`] - An IdeviceProvider. The provider is consumed and may not
///   be used again, regardless of whether this call succeeds or fails.
/// * [`handle`] - On success, set to a newly allocated WdaClientHandle.
///
/// # Returns
/// An IdeviceFfiError on error, null on success.
///
/// # Safety
/// `provider` must be a valid pointer to a handle allocated by this library.
/// The provider is consumed, and may not be used again.
/// `handle` must be a valid, non-null pointer to a location where the handle will be stored.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_new(
    provider: *mut IdeviceProviderHandle,
    handle: *mut *mut WdaClientHandle,
) -> *mut IdeviceFfiError {
    if provider.is_null() || handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let provider = unsafe { Box::from_raw(provider) }.0;
    let boxed = Box::new(WdaClientHandle {
        provider,
        ports: WdaPorts {
            http: DEFAULT_WDA_PORT,
            mjpeg: DEFAULT_WDA_MJPEG_PORT,
        },
        timeout: DEFAULT_WDA_TIMEOUT,
        session_id: None,
    });
    unsafe { *handle = Box::into_raw(boxed) };
    null_mut()
}

/// Frees a WDA client handle.
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library or NULL.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_free(handle: *mut WdaClientHandle) {
    if !handle.is_null() {
        let _ = unsafe { Box::from_raw(handle) };
    }
}

/// Sets the device-side WDA HTTP and MJPEG ports.
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_set_ports(
    handle: *mut WdaClientHandle,
    http: u16,
    mjpeg: u16,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let h = unsafe { &mut *handle };
    h.ports = WdaPorts { http, mjpeg };
    null_mut()
}

/// Sets the per-request timeout in milliseconds.
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_set_timeout_ms(
    handle: *mut WdaClientHandle,
    ms: u64,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let h = unsafe { &mut *handle };
    h.timeout = Duration::from_millis(ms);
    null_mut()
}

/// Reads the configured device-side WDA ports.
///
/// # Safety
/// All pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_get_ports(
    handle: *mut WdaClientHandle,
    out_http: *mut u16,
    out_mjpeg: *mut u16,
) -> *mut IdeviceFfiError {
    if handle.is_null() || out_http.is_null() || out_mjpeg.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let h = unsafe { &*handle };
    unsafe {
        *out_http = h.ports.http;
        *out_mjpeg = h.ports.mjpeg;
    }
    null_mut()
}

/// Returns the currently tracked session id, or NULL if none.
///
/// # Arguments
/// * [`handle`] - The WDA client handle.
/// * [`out_str`] - On success, set to a heap-allocated UTF-8 string, or NULL
///   if no session is tracked. Free with `idevice_string_free` if non-null.
///
/// # Safety
/// All pointers must be valid; `out_str` must be non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_session_id(
    handle: *mut WdaClientHandle,
    out_str: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || out_str.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let h = unsafe { &*handle };
    let raw = match &h.session_id {
        Some(s) => CString::new(s.as_str()).unwrap_or_default().into_raw(),
        None => null_mut(),
    };
    unsafe { *out_str = raw };
    null_mut()
}

/// Fetches `/status` from the WDA HTTP endpoint and returns the JSON response.
///
/// # Arguments
/// * [`handle`] - The WDA client handle.
/// * [`out_json`] - On success, set to a heap-allocated JSON string. Free with
///   `idevice_string_free`.
///
/// # Safety
/// All pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_status(
    handle: *mut WdaClientHandle,
    out_json: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || out_json.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move { client.status().await });
    write_json(res, out_json)
}

/// Waits until WDA begins responding on its HTTP endpoint.
///
/// # Safety
/// All pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_wait_until_ready(
    handle: *mut WdaClientHandle,
    timeout_ms: u64,
    out_json: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || out_json.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .wait_until_ready(Duration::from_millis(timeout_ms))
            .await
    });
    write_json(res, out_json)
}

/// Starts a WDA session and stores the resulting session id on the handle.
///
/// # Arguments
/// * [`handle`] - The WDA client handle.
/// * [`bundle_id`] - Optional bundle identifier; pass NULL for an anonymous session.
/// * [`out_session_id`] - On success, set to a heap-allocated UTF-8 string.
///   Free with `idevice_string_free`.
///
/// # Safety
/// `handle` and `out_session_id` must be valid and non-null. `bundle_id` may be NULL.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_start_session(
    handle: *mut WdaClientHandle,
    bundle_id: *const c_char,
    out_session_id: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || out_session_id.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let bundle_id = match cstr_to_opt(bundle_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &mut *handle };
    let mut client = h.build_client();
    let res = run_sync_local(async move { client.start_session(bundle_id.as_deref()).await });

    match res {
        Ok(sid) => {
            h.session_id = Some(sid.clone());
            unsafe { *out_session_id = CString::new(sid).unwrap_or_default().into_raw() };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Deletes a WDA session.
///
/// # Safety
/// `handle` and `session_id` must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_delete_session(
    handle: *mut WdaClientHandle,
    session_id: *const c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || session_id.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let session_id = match cstr_to_string(session_id) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let h = unsafe { &mut *handle };
    let client = h.build_client();
    let res = run_sync_local(async move { client.delete_session(&session_id).await });
    match res {
        Ok(_) => {
            h.session_id = None;
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Finds a single element and returns its WDA element id.
///
/// # Safety
/// `handle`, `using`, `value`, and `out_element_id` must be valid and non-null.
/// `session_id` may be NULL to use the handle's tracked session.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_find_element(
    handle: *mut WdaClientHandle,
    using: *const c_char,
    value: *const c_char,
    session_id: *const c_char,
    out_element_id: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || using.is_null() || value.is_null() || out_element_id.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let using = match cstr_to_string(using) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let value = match cstr_to_string(value) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .find_element(&using, &value, session_id.as_deref())
            .await
    });
    write_string(res, out_element_id)
}

/// Finds multiple elements and returns their WDA element ids.
///
/// # Arguments
/// * [`out_array`] - On success, set to a heap-allocated array of NUL-terminated strings.
/// * [`out_count`] - On success, set to the number of strings.
///
/// Free the array with `wda_client_string_array_free`.
///
/// # Safety
/// All non-optional pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_find_elements(
    handle: *mut WdaClientHandle,
    using: *const c_char,
    value: *const c_char,
    session_id: *const c_char,
    out_array: *mut *mut *mut c_char,
    out_count: *mut usize,
) -> *mut IdeviceFfiError {
    if handle.is_null()
        || using.is_null()
        || value.is_null()
        || out_array.is_null()
        || out_count.is_null()
    {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let using = match cstr_to_string(using) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let value = match cstr_to_string(value) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .find_elements(&using, &value, session_id.as_deref())
            .await
    });

    match res {
        Ok(elements) => {
            let mut raw: Box<[*mut c_char]> = elements
                .into_iter()
                .map(|s| CString::new(s).unwrap_or_default().into_raw())
                .collect::<Vec<_>>()
                .into_boxed_slice();
            unsafe {
                *out_array = raw.as_mut_ptr();
                *out_count = raw.len();
            }
            std::mem::forget(raw);
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Frees an array of strings allocated by `wda_client_find_elements`.
///
/// # Safety
/// `arr` must be a pointer returned by `wda_client_find_elements` with the
/// matching `count`, or NULL.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_string_array_free(arr: *mut *mut c_char, count: usize) {
    if arr.is_null() {
        return;
    }
    let slice = unsafe { Box::from_raw(std::ptr::slice_from_raw_parts_mut(arr, count)) };
    for &p in slice.iter() {
        if !p.is_null() {
            let _ = unsafe { CString::from_raw(p) };
        }
    }
}

/// Returns a raw attribute value as a JSON-encoded string.
///
/// # Safety
/// All non-optional pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_element_attribute(
    handle: *mut WdaClientHandle,
    element_id: *const c_char,
    name: *const c_char,
    session_id: *const c_char,
    out_json: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || element_id.is_null() || name.is_null() || out_json.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let element_id = match cstr_to_string(element_id) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let name = match cstr_to_string(name) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .element_attribute(&element_id, &name, session_id.as_deref())
            .await
    });
    write_json(res, out_json)
}

/// Returns the element text-like value as a string.
///
/// # Safety
/// All non-optional pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_element_text(
    handle: *mut WdaClientHandle,
    element_id: *const c_char,
    session_id: *const c_char,
    out_str: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || element_id.is_null() || out_str.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let element_id = match cstr_to_string(element_id) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .element_text(&element_id, session_id.as_deref())
            .await
    });
    write_string(res, out_str)
}

/// Returns the element bounds rectangle as a JSON-encoded string.
///
/// # Safety
/// All non-optional pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_element_rect(
    handle: *mut WdaClientHandle,
    element_id: *const c_char,
    session_id: *const c_char,
    out_json: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || element_id.is_null() || out_json.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let element_id = match cstr_to_string(element_id) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .element_rect(&element_id, session_id.as_deref())
            .await
    });
    write_json(res, out_json)
}

/// Returns whether an element is displayed.
///
/// # Safety
/// All non-optional pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_element_displayed(
    handle: *mut WdaClientHandle,
    element_id: *const c_char,
    session_id: *const c_char,
    out_bool: *mut bool,
) -> *mut IdeviceFfiError {
    if handle.is_null() || element_id.is_null() || out_bool.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let element_id = match cstr_to_string(element_id) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .element_displayed(&element_id, session_id.as_deref())
            .await
    });
    write_bool(res, out_bool)
}

/// Returns whether an element is enabled.
///
/// # Safety
/// All non-optional pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_element_enabled(
    handle: *mut WdaClientHandle,
    element_id: *const c_char,
    session_id: *const c_char,
    out_bool: *mut bool,
) -> *mut IdeviceFfiError {
    if handle.is_null() || element_id.is_null() || out_bool.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let element_id = match cstr_to_string(element_id) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .element_enabled(&element_id, session_id.as_deref())
            .await
    });
    write_bool(res, out_bool)
}

/// Returns whether an element is selected.
///
/// # Safety
/// All non-optional pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_element_selected(
    handle: *mut WdaClientHandle,
    element_id: *const c_char,
    session_id: *const c_char,
    out_bool: *mut bool,
) -> *mut IdeviceFfiError {
    if handle.is_null() || element_id.is_null() || out_bool.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let element_id = match cstr_to_string(element_id) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .element_selected(&element_id, session_id.as_deref())
            .await
    });
    write_bool(res, out_bool)
}

/// Clicks an element by its WDA element id.
///
/// # Safety
/// `handle` and `element_id` must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_click(
    handle: *mut WdaClientHandle,
    element_id: *const c_char,
    session_id: *const c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || element_id.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let element_id = match cstr_to_string(element_id) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move { client.click(&element_id, session_id.as_deref()).await });
    void_result(res)
}

/// Sends text input to the currently focused element.
///
/// # Safety
/// `handle` and `text` must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_send_keys(
    handle: *mut WdaClientHandle,
    text: *const c_char,
    session_id: *const c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || text.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let text = match cstr_to_string(text) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move { client.send_keys(&text, session_id.as_deref()).await });
    void_result(res)
}

/// Presses a hardware button through WDA.
///
/// # Safety
/// `handle` and `name` must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_press_button(
    handle: *mut WdaClientHandle,
    name: *const c_char,
    session_id: *const c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || name.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let name = match cstr_to_string(name) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res =
        run_sync_local(async move { client.press_button(&name, session_id.as_deref()).await });
    void_result(res)
}

/// Unlocks the device via WDA.
///
/// # Safety
/// `handle` must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_unlock(
    handle: *mut WdaClientHandle,
    session_id: *const c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move { client.unlock(session_id.as_deref()).await });
    void_result(res)
}

/// Swipes from one coordinate to another.
///
/// # Safety
/// `handle` must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_swipe(
    handle: *mut WdaClientHandle,
    start_x: i64,
    start_y: i64,
    end_x: i64,
    end_y: i64,
    duration: f64,
    session_id: *const c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .swipe(
                start_x,
                start_y,
                end_x,
                end_y,
                duration,
                session_id.as_deref(),
            )
            .await
    });
    void_result(res)
}

/// Performs a tap gesture.
///
/// `Option<f64>` arguments are encoded as `(has, value)` pairs. When `has_*`
/// is false the underlying value is ignored.
///
/// # Safety
/// `handle` must be valid and non-null. Optional pointers may be NULL.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_tap(
    handle: *mut WdaClientHandle,
    has_x: bool,
    x: f64,
    has_y: bool,
    y: f64,
    element_id: *const c_char,
    session_id: *const c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let element_id = match cstr_to_opt(element_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let x = if has_x { Some(x) } else { None };
    let y = if has_y { Some(y) } else { None };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .tap(x, y, element_id.as_deref(), session_id.as_deref())
            .await
    });
    void_result(res)
}

/// Performs a double-tap gesture.
///
/// # Safety
/// `handle` must be valid and non-null. Optional pointers may be NULL.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_double_tap(
    handle: *mut WdaClientHandle,
    has_x: bool,
    x: f64,
    has_y: bool,
    y: f64,
    element_id: *const c_char,
    session_id: *const c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let element_id = match cstr_to_opt(element_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let x = if has_x { Some(x) } else { None };
    let y = if has_y { Some(y) } else { None };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .double_tap(x, y, element_id.as_deref(), session_id.as_deref())
            .await
    });
    void_result(res)
}

/// Performs a long-press gesture.
///
/// # Safety
/// `handle` must be valid and non-null. Optional pointers may be NULL.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_touch_and_hold(
    handle: *mut WdaClientHandle,
    duration: f64,
    has_x: bool,
    x: f64,
    has_y: bool,
    y: f64,
    element_id: *const c_char,
    session_id: *const c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let element_id = match cstr_to_opt(element_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let x = if has_x { Some(x) } else { None };
    let y = if has_y { Some(y) } else { None };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .touch_and_hold(duration, x, y, element_id.as_deref(), session_id.as_deref())
            .await
    });
    void_result(res)
}

/// Scrolls the current view or an element using a WDA mobile command.
///
/// `Option<bool>` arguments are encoded as `(has, value)`.
///
/// # Safety
/// `handle` must be valid and non-null. Optional string arguments may be NULL.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_scroll(
    handle: *mut WdaClientHandle,
    direction: *const c_char,
    name: *const c_char,
    predicate_string: *const c_char,
    has_to_visible: bool,
    to_visible: bool,
    element_id: *const c_char,
    session_id: *const c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let direction = match cstr_to_opt(direction) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let name = match cstr_to_opt(name) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let predicate_string = match cstr_to_opt(predicate_string) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let element_id = match cstr_to_opt(element_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let to_visible = if has_to_visible {
        Some(to_visible)
    } else {
        None
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .scroll(
                direction.as_deref(),
                name.as_deref(),
                predicate_string.as_deref(),
                to_visible,
                element_id.as_deref(),
                session_id.as_deref(),
            )
            .await
    });
    void_result(res)
}

/// Returns the current UI source tree as XML.
///
/// # Safety
/// `handle` and `out_str` must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_source(
    handle: *mut WdaClientHandle,
    session_id: *const c_char,
    out_str: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || out_str.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move { client.source(session_id.as_deref()).await });
    write_string(res, out_str)
}

/// Returns a PNG screenshot as raw bytes.
///
/// # Arguments
/// * [`out_bytes`] - On success, set to a heap-allocated PNG buffer.
/// * [`out_len`] - On success, set to the buffer length in bytes.
///
/// Free the buffer with `idevice_data_free`.
///
/// # Safety
/// All non-optional pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_screenshot(
    handle: *mut WdaClientHandle,
    session_id: *const c_char,
    out_bytes: *mut *mut u8,
    out_len: *mut usize,
) -> *mut IdeviceFfiError {
    if handle.is_null() || out_bytes.is_null() || out_len.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move { client.screenshot(session_id.as_deref()).await });

    match res {
        Ok(bytes) => {
            let mut boxed = bytes.into_boxed_slice();
            unsafe {
                *out_bytes = boxed.as_mut_ptr();
                *out_len = boxed.len();
            }
            std::mem::forget(boxed);
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Returns the current window size payload from WDA.
///
/// # Safety
/// All non-optional pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_window_size(
    handle: *mut WdaClientHandle,
    session_id: *const c_char,
    out_json: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || out_json.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move { client.window_size(session_id.as_deref()).await });
    write_json(res, out_json)
}

/// Returns the current viewport rectangle.
///
/// # Safety
/// All non-optional pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_viewport_rect(
    handle: *mut WdaClientHandle,
    session_id: *const c_char,
    out_json: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || out_json.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move { client.viewport_rect(session_id.as_deref()).await });
    write_json(res, out_json)
}

/// Returns the current orientation as a string.
///
/// # Safety
/// All non-optional pointers must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_orientation(
    handle: *mut WdaClientHandle,
    session_id: *const c_char,
    out_str: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || out_str.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move { client.orientation(session_id.as_deref()).await });
    write_string(res, out_str)
}

/// Launches or activates an application via WDA.
///
/// # Arguments
/// * [`bundle_id`] - The bundle identifier of the app to launch.
/// * [`arguments`] - Optional array of argument strings; pass NULL for none.
/// * [`arguments_count`] - Number of strings in `arguments`; ignored if NULL.
/// * [`environment_json`] - Optional JSON object string of environment variables; pass NULL for none.
///
/// # Safety
/// `handle`, `bundle_id`, and `out_json` must be valid and non-null. Optional
/// pointers may be NULL.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_launch_app(
    handle: *mut WdaClientHandle,
    bundle_id: *const c_char,
    arguments: *const *const c_char,
    arguments_count: usize,
    environment_json: *const c_char,
    session_id: *const c_char,
    out_json: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || bundle_id.is_null() || out_json.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let bundle_id = match cstr_to_string(bundle_id) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let args_vec: Option<Vec<String>> = if arguments.is_null() {
        None
    } else {
        let slice = unsafe { std::slice::from_raw_parts(arguments, arguments_count) };
        let mut v = Vec::with_capacity(slice.len());
        for &p in slice {
            if p.is_null() {
                return ffi_err!(IdeviceError::FfiInvalidArg);
            }
            match unsafe { CStr::from_ptr(p) }.to_str() {
                Ok(s) => v.push(s.to_owned()),
                Err(_) => return ffi_err!(IdeviceError::FfiInvalidString),
            }
        }
        Some(v)
    };

    let env_map: Option<Map<String, Value>> = match cstr_to_opt(environment_json) {
        Ok(Some(s)) => match serde_json::from_str::<Value>(&s) {
            Ok(Value::Object(map)) => Some(map),
            _ => return ffi_err!(IdeviceError::FfiInvalidArg),
        },
        Ok(None) => None,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .launch_app(
                &bundle_id,
                args_vec.as_deref(),
                env_map.as_ref(),
                session_id.as_deref(),
            )
            .await
    });
    write_json(res, out_json)
}

/// Activates an already running application.
///
/// # Safety
/// `handle`, `bundle_id`, and `out_json` must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_activate_app(
    handle: *mut WdaClientHandle,
    bundle_id: *const c_char,
    session_id: *const c_char,
    out_json: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || bundle_id.is_null() || out_json.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let bundle_id = match cstr_to_string(bundle_id) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let h = unsafe { &*handle };
    let client = h.build_client();
    let res =
        run_sync_local(async move { client.activate_app(&bundle_id, session_id.as_deref()).await });
    write_json(res, out_json)
}

/// Terminates an application and returns whether termination succeeded.
///
/// # Safety
/// `handle`, `bundle_id`, and `out_bool` must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_terminate_app(
    handle: *mut WdaClientHandle,
    bundle_id: *const c_char,
    session_id: *const c_char,
    out_bool: *mut bool,
) -> *mut IdeviceFfiError {
    if handle.is_null() || bundle_id.is_null() || out_bool.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let bundle_id = match cstr_to_string(bundle_id) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .terminate_app(&bundle_id, session_id.as_deref())
            .await
    });
    write_bool(res, out_bool)
}

/// Queries the XCTest application state for the given bundle id.
///
/// # Safety
/// `handle`, `bundle_id`, and `out_state` must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_query_app_state(
    handle: *mut WdaClientHandle,
    bundle_id: *const c_char,
    session_id: *const c_char,
    out_state: *mut i64,
) -> *mut IdeviceFfiError {
    if handle.is_null() || bundle_id.is_null() || out_state.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let bundle_id = match cstr_to_string(bundle_id) {
        Ok(s) => s,
        Err(e) => return ffi_err!(e),
    };
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move {
        client
            .query_app_state(&bundle_id, session_id.as_deref())
            .await
    });
    match res {
        Ok(v) => {
            unsafe { *out_state = v };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Backgrounds the current app for the given number of seconds.
///
/// `Option<f64>` is encoded as `(has_seconds, seconds)`.
///
/// # Safety
/// `handle` and `out_json` must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_background_app(
    handle: *mut WdaClientHandle,
    has_seconds: bool,
    seconds: f64,
    session_id: *const c_char,
    out_json: *mut *mut c_char,
) -> *mut IdeviceFfiError {
    if handle.is_null() || out_json.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let seconds = if has_seconds { Some(seconds) } else { None };

    let h = unsafe { &*handle };
    let client = h.build_client();
    let res =
        run_sync_local(async move { client.background_app(seconds, session_id.as_deref()).await });
    write_json(res, out_json)
}

/// Returns whether the device is currently locked.
///
/// # Safety
/// `handle` and `out_bool` must be valid and non-null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn wda_client_is_locked(
    handle: *mut WdaClientHandle,
    session_id: *const c_char,
    out_bool: *mut bool,
) -> *mut IdeviceFfiError {
    if handle.is_null() || out_bool.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }
    let session_id = match cstr_to_opt(session_id) {
        Ok(o) => o,
        Err(e) => return ffi_err!(e),
    };
    let h = unsafe { &*handle };
    let client = h.build_client();
    let res = run_sync_local(async move { client.is_locked(session_id.as_deref()).await });
    write_bool(res, out_bool)
}

// --- helpers (private) ---------------------------------------------------

fn cstr_to_string(p: *const c_char) -> Result<String, IdeviceError> {
    if p.is_null() {
        return Err(IdeviceError::FfiInvalidArg);
    }
    unsafe { CStr::from_ptr(p) }
        .to_str()
        .map(ToOwned::to_owned)
        .map_err(|_| IdeviceError::FfiInvalidString)
}

fn cstr_to_opt(p: *const c_char) -> Result<Option<String>, IdeviceError> {
    if p.is_null() {
        Ok(None)
    } else {
        cstr_to_string(p).map(Some)
    }
}

fn write_string(res: Result<String, IdeviceError>, out: *mut *mut c_char) -> *mut IdeviceFfiError {
    match res {
        Ok(s) => {
            unsafe { *out = CString::new(s).unwrap_or_default().into_raw() };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

fn write_json(res: Result<Value, IdeviceError>, out: *mut *mut c_char) -> *mut IdeviceFfiError {
    match res {
        Ok(v) => match serde_json::to_string(&v) {
            Ok(s) => {
                unsafe { *out = CString::new(s).unwrap_or_default().into_raw() };
                null_mut()
            }
            Err(_) => ffi_err!(IdeviceError::UnexpectedResponse(
                "failed to serialize WDA response".into()
            )),
        },
        Err(e) => ffi_err!(e),
    }
}

fn write_bool(res: Result<bool, IdeviceError>, out: *mut bool) -> *mut IdeviceFfiError {
    match res {
        Ok(b) => {
            unsafe { *out = b };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

fn void_result(res: Result<(), IdeviceError>) -> *mut IdeviceFfiError {
    match res {
        Ok(_) => null_mut(),
        Err(e) => ffi_err!(e),
    }
}
