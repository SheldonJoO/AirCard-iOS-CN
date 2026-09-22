//! Logging spine: forwards idevice's `tracing` events through the FFI callback.
//!
//! We use a global atomic to store the callback pointer and ctx, then install a
//! simple tracing subscriber that calls it. This avoids the Send+Sync closure
//! requirements of the `with_writer` API.

use std::ffi::{c_char, c_void, CString};
use std::io;
use std::sync::atomic::{AtomicPtr, AtomicUsize, Ordering};
use std::sync::OnceLock;

pub type LogCallback = Option<extern "C" fn(ctx: *mut c_void, msg: *const c_char)>;

// Global callback state — set once at init time.
static LOG_CB: AtomicUsize = AtomicUsize::new(0); // fn pointer
static LOG_CTX: AtomicPtr<c_void> = AtomicPtr::new(std::ptr::null_mut());
static INIT: OnceLock<()> = OnceLock::new();

/// Call the installed callback with `msg`, if one was registered.
pub fn emit(msg: &str) {
    let fn_addr = LOG_CB.load(Ordering::Relaxed);
    if fn_addr == 0 {
        return;
    }
    // Safety: fn_addr was stored from a valid extern "C" fn pointer.
    let cb: extern "C" fn(*mut c_void, *const c_char) =
        unsafe { std::mem::transmute(fn_addr) };
    let ctx = LOG_CTX.load(Ordering::Relaxed);
    if let Ok(c) = CString::new(msg) {
        cb(ctx, c.as_ptr());
    }
}

/// A tracing `io::Write` that forwards to the global callback.
struct FfiWriter;

impl io::Write for FfiWriter {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        let msg = String::from_utf8_lossy(buf)
            .trim_end_matches('\n')
            .to_string();
        if !msg.is_empty() {
            emit(&msg);
        }
        Ok(buf.len())
    }
    fn flush(&mut self) -> io::Result<()> { Ok(()) }
}

// FfiWriter has no fields; it's trivially Send+Sync.
unsafe impl Send for FfiWriter {}
unsafe impl Sync for FfiWriter {}

/// Install the global tracing subscriber. Returns 0 on success, 1 if already
/// initialised. Call once at launch (from Swift, at app startup).
pub fn init(cb: LogCallback, ctx: *mut c_void) -> i32 {
    if INIT.set(()).is_err() {
        return 1; // already initialised
    }

    if let Some(cb_fn) = cb {
        // Store the raw fn-pointer address (usize is always pointer-sized).
        LOG_CB.store(cb_fn as usize, Ordering::Relaxed);
        LOG_CTX.store(ctx, Ordering::Relaxed);
    }

    let subscriber = tracing_subscriber::fmt()
        .with_writer(|| FfiWriter)
        .with_ansi(false)
        .finish();
    let _ = tracing::subscriber::set_global_default(subscriber);
    0
}
