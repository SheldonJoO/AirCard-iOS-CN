//! Shared FFI utilities.

use std::ffi::{c_char, CStr, CString};

/// Convert an optional C string to an owned Rust string, returning `default`
/// for null or invalid input.
pub fn opt_str(p: *const c_char, default: &str) -> String {
    if p.is_null() {
        return default.to_owned();
    }
    unsafe { CStr::from_ptr(p) }
        .to_str()
        .unwrap_or(default)
        .to_owned()
}

/// Heap-allocate a C string from any `Display`-able value. The caller is
/// responsible for freeing it with `string_free`.
pub fn cstr(s: impl std::fmt::Display) -> *mut c_char {
    let s = format!("{s}");
    CString::new(s)
        .unwrap_or_else(|_| CString::new("(null bytes in string)").unwrap())
        .into_raw()
}

/// Free any `*mut c_char` returned by this library.
///
/// # Safety
/// `p` must be null or a pointer previously returned by `cstr`.
pub unsafe fn string_free(p: *mut c_char) {
    if !p.is_null() {
        drop(CString::from_raw(p));
    }
}

/// Runs the closure on a dedicated thread with a 4MB stack to prevent stack overflow
/// on platforms/threads with tiny stack limits (like Swift Concurrency cooperative threads
/// and iOS GCD worker threads, which only have 512KB).
pub fn run_with_large_stack<F, R>(name: &str, f: F) -> Result<R, String>
where
    F: FnOnce() -> R + Send + 'static,
    R: Send + 'static,
{
    std::thread::Builder::new()
        .name(name.to_string())
        .stack_size(4 * 1024 * 1024)
        .spawn(f)
        .map_err(|e| format!("创建工作线程 '{name}' 失败：{e}"))?
        .join()
        .map_err(|panic_err| format!("Worker thread '{name}' panicked: {panic_err:?}"))
}
