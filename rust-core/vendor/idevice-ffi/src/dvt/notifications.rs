// Jackson Coxson

use std::{ffi::CString, ptr::null_mut};

use idevice::{ReadWrite, dvt::notifications::NotificationsClient};

use crate::{IdeviceFfiError, dvt::remote_server::RemoteServerHandle, ffi_err, run_sync};

pub struct NotificationsHandle<'a>(pub NotificationsClient<'a, Box<dyn ReadWrite>>);

/// A notification from the mobile notifications instruments channel
#[repr(C)]
pub struct IdeviceNotificationInfo {
    pub notification_type: *mut std::ffi::c_char,
    pub mach_absolute_time: i64,
    pub exec_name: *mut std::ffi::c_char,
    pub app_name: *mut std::ffi::c_char,
    pub pid: u32,
    pub state_description: *mut std::ffi::c_char,
}

/// Frees an IdeviceNotificationInfo and its heap-allocated string fields
///
/// # Safety
/// `info` must be a valid pointer allocated by this library or NULL
#[unsafe(no_mangle)]
pub unsafe extern "C" fn notifications_info_free(info: *mut IdeviceNotificationInfo) {
    if info.is_null() {
        return;
    }
    let n = unsafe { Box::from_raw(info) };
    if !n.notification_type.is_null() {
        let _ = unsafe { CString::from_raw(n.notification_type) };
    }
    if !n.exec_name.is_null() {
        let _ = unsafe { CString::from_raw(n.exec_name) };
    }
    if !n.app_name.is_null() {
        let _ = unsafe { CString::from_raw(n.app_name) };
    }
    if !n.state_description.is_null() {
        let _ = unsafe { CString::from_raw(n.state_description) };
    }
}

/// Creates a new NotificationsClient from a RemoteServerClient
///
/// # Safety
/// `server` must be a valid pointer to a handle allocated by this library
/// `handle` must be a valid pointer to a location where the handle will be stored
#[unsafe(no_mangle)]
pub unsafe extern "C" fn notifications_new(
    server: *mut RemoteServerHandle,
    handle: *mut *mut NotificationsHandle<'static>,
) -> *mut IdeviceFfiError {
    if server.is_null() || handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let server = unsafe { &mut (*server).0 };
    let res = run_sync(async move { NotificationsClient::new(server).await });

    match res {
        Ok(client) => {
            let boxed = Box::new(NotificationsHandle(client));
            unsafe { *handle = Box::into_raw(boxed) };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}

/// Frees a NotificationsClient handle
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library or NULL
#[unsafe(no_mangle)]
pub unsafe extern "C" fn notifications_free(handle: *mut NotificationsHandle<'static>) {
    if !handle.is_null() {
        let _ = unsafe { Box::from_raw(handle) };
    }
}

/// Enables application state and memory notifications on the device.
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library
#[unsafe(no_mangle)]
pub unsafe extern "C" fn notifications_start(
    handle: *mut NotificationsHandle<'static>,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let client = unsafe { &mut (*handle).0 };
    let res = run_sync(async move { client.start_notifications().await });

    match res {
        Ok(_) => null_mut(),
        Err(e) => ffi_err!(e),
    }
}

/// Disables application state and memory notifications on the device.
///
/// # Safety
/// `handle` must be a valid pointer to a handle allocated by this library
#[unsafe(no_mangle)]
pub unsafe extern "C" fn notifications_stop(
    handle: *mut NotificationsHandle<'static>,
) -> *mut IdeviceFfiError {
    if handle.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let client = unsafe { &mut (*handle).0 };
    let res = run_sync(async move { client.stop_notifications().await });

    match res {
        Ok(_) => null_mut(),
        Err(e) => ffi_err!(e),
    }
}

/// Reads the next notification pushed by the device. Blocks until a notification arrives.
///
/// # Arguments
/// * [`handle`] - The NotificationsClient handle
/// * [`info_out`] - On success, set to a heap-allocated IdeviceNotificationInfo
///
/// # Returns
/// An IdeviceFfiError on error, null on success
///
/// # Safety
/// All pointers must be valid and non-null. Free the info with `notifications_info_free`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn notifications_get_next(
    handle: *mut NotificationsHandle<'static>,
    info_out: *mut *mut IdeviceNotificationInfo,
) -> *mut IdeviceFfiError {
    if handle.is_null() || info_out.is_null() {
        return ffi_err!(IdeviceError::FfiInvalidArg);
    }

    let client = unsafe { &mut (*handle).0 };
    let res = run_sync(async move { client.get_notification().await });

    match res {
        Ok(info) => {
            let c_info = IdeviceNotificationInfo {
                notification_type: CString::new(info.notification_type)
                    .unwrap_or_default()
                    .into_raw(),
                mach_absolute_time: info.mach_absolute_time,
                exec_name: CString::new(info.exec_name).unwrap_or_default().into_raw(),
                app_name: CString::new(info.app_name).unwrap_or_default().into_raw(),
                pid: info.pid,
                state_description: CString::new(info.state_description)
                    .unwrap_or_default()
                    .into_raw(),
            };
            unsafe { *info_out = Box::into_raw(Box::new(c_info)) };
            null_mut()
        }
        Err(e) => ffi_err!(e),
    }
}
