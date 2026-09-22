//! Pairing module — RPPairing host, adapted from SideInstaller's pairing.rs.
//!
//! mDNS advertising is done in Swift via NetService (no iOS multicast entitlement
//! needed). The Rust side binds a TCP listener, passes the service ID, port, and
//! TXT records to Swift through `ready_cb`, then drives the handshake.

use std::ffi::{c_char, c_void, CString};
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::ptr;

use idevice::remote_pairing::{
    PairableHost, PairableHostInfo, RpPairingFile, RpPairingSocket,
};
use tokio::net::TcpListener;

use crate::ffi_util::{cstr, opt_str};

// ---------------------------------------------------------------------------
// Types exposed to C / Swift

pub type ALPairReadyCb = Option<
    extern "C" fn(
        ctx: *mut c_void,
        service_id: *const c_char,
        port: u16,
        txt_keys: *const *const c_char,
        txt_vals: *const *const c_char,
        txt_count: usize,
    ),
>;

pub type ALPairPinCb = Option<extern "C" fn(pin: *const c_char, ctx: *mut c_void)>;

/// Heap-allocated result of one pairing run. Free with `al_pairing_result_free`.
#[repr(C)]
pub struct ALPairResult {
    pub error: *mut c_char,
    pub device_name: *mut c_char,
    pub device_model: *mut c_char,
    pub device_udid: *mut c_char,
    pub pairing_file_path: *mut c_char,
    pub host_alt_irk_hex: *mut c_char,
}

impl ALPairResult {
    fn empty() -> Self {
        Self {
            error: ptr::null_mut(),
            device_name: ptr::null_mut(),
            device_model: ptr::null_mut(),
            device_udid: ptr::null_mut(),
            pairing_file_path: ptr::null_mut(),
            host_alt_irk_hex: ptr::null_mut(),
        }
    }
}

// Callbacks carry raw pointers; the Swift side ensures they outlive the call.
struct Cbs {
    ready: ALPairReadyCb,
    pin: ALPairPinCb,
    ctx: *mut c_void,
}
unsafe impl Send for Cbs {}

// ---------------------------------------------------------------------------
// Public FFI entry point

/// # Safety
/// All `*const c_char` args must be null or valid C strings.
/// `out` must point to a writable `ALPairResult`.
#[allow(clippy::too_many_arguments)]
pub unsafe fn run_host(
    bind_addr: *const c_char,
    port: u16,
    name: *const c_char,
    model: *const c_char,
    out_path: *const c_char,
    host_alt_irk_hex: *const c_char,
    ready_cb: ALPairReadyCb,
    pin_cb: ALPairPinCb,
    ctx: *mut c_void,
    out: *mut ALPairResult,
) -> i32 {
    if out.is_null() {
        return 2;
    }
    *out = ALPairResult::empty();

    let bind_addr = opt_str(bind_addr, "0.0.0.0");
    let name = opt_str(name, "Airlift");
    let model = opt_str(model, "Mac17,7");
    let out_path = opt_str(out_path, "airlift_pairing.plist");
    let saved_alt_irk = parse_alt_irk(&opt_str(host_alt_irk_hex, ""));
    let cbs = Cbs { ready: ready_cb, pin: pin_cb, ctx };

    let res = crate::ffi_util::run_with_large_stack("al_pairing_run_host", move || {
        idevice_ffi::run_sync_local(async_run_host(
            bind_addr, port, name, model, out_path, saved_alt_irk, cbs,
        ))
    });

    match res {
        Ok(Ok((dev_name, dev_model, udid, path, irk_hex))) => {
            (*out).device_name = cstr(dev_name);
            (*out).device_model = cstr(dev_model);
            (*out).device_udid = cstr(udid);
            (*out).pairing_file_path = cstr(path);
            (*out).host_alt_irk_hex = cstr(irk_hex);
            0
        }
        Ok(Err(e)) => {
            (*out).error = cstr(e);
            1
        }
        Err(panic_msg) => {
            (*out).error = cstr(panic_msg);
            1
        }
    }
}

async fn async_run_host(
    bind_addr: String,
    port: u16,
    name: String,
    model: String,
    out_path: String,
    saved_alt_irk: Option<[u8; 16]>,
    cbs: Cbs,
) -> Result<(String, String, String, String, String), String> {
    tracing::info!("RPPairing：正在监听 {bind_addr}:{port}");
    let ip: IpAddr = bind_addr.parse().unwrap_or(IpAddr::V4(Ipv4Addr::UNSPECIFIED));
    let listener = TcpListener::bind(SocketAddr::new(ip, port))
        .await
        .map_err(|e| format!("failed to bind {bind_addr}:{port}: {e}"))?;
    let bound_port = listener
        .local_addr()
        .map_err(|e| format!("no local addr: {e}"))?
        .port();
    tracing::info!("RPPairing：已在端口 {bound_port} 上监听");

    let mut pairing_file = match RpPairingFile::read_from_file(&out_path).await {
        Ok(mut existing) => {
            existing.alt_irk = None;
            tracing::info!("RPPairing：复用 {out_path} 中的主机密钥对");
            existing
        }
        Err(_) => {
            tracing::info!("RPPairing：正在生成新的主机密钥对");
            RpPairingFile::generate(&name)
        }
    };

    let mut host_info = PairableHostInfo::generate(&name, &model);
    if let Some(irk) = saved_alt_irk {
        host_info.alt_irk = irk;
        tracing::info!("RPPairing：复用已存储的 altIRK");
    }
    let host_alt_irk = host_info.alt_irk;
    let service_id = pairing_file.identifier.clone();

    // Advertise: hand the Bonjour details to Swift via the ready callback.
    emit_ready(&cbs, &service_id, bound_port, &host_info);

    tracing::info!("RPPairing：正在端口 {bound_port} 上等待设备连接…");
    let (stream, peer_addr) = listener
        .accept()
        .await
        .map_err(|e| format!("accept failed: {e}"))?;
    tracing::info!("RPPairing：设备已从 {peer_addr} 连接");

    let socket = RpPairingSocket::new_device(stream);
    let mut host = PairableHost::new(socket, host_info);

    // Clone ctx pointer so the closure can capture it.
    let pin_cb = cbs.pin;
    let pin_ctx = cbs.ctx;

    let peer_info = host
        .accept(&mut pairing_file, move |pin| {
            let pin_cb = pin_cb;
            let pin_ctx = pin_ctx;
            async move {
                tracing::info!("RPPairing：已生成配对码 —— {pin}");
                if let Some(cb) = pin_cb {
                    if let Ok(c) = CString::new(pin.as_str()) {
                        cb(c.as_ptr(), pin_ctx);
                    }
                }
            }
        })
        .await
        .map_err(|e| format!("配对失败：{e}"))?;
    tracing::info!(
        "RPPairing：握手完成 —— {}（{}）",
        peer_info.name, peer_info.model
    );

    pairing_file
        .write_to_file(&out_path)
        .await
        .map_err(|e| format!("写入配对文件失败：{e}"))?;

    let size = tokio::fs::metadata(&out_path)
        .await
        .map(|m| m.len())
        .unwrap_or(0);
    if size == 0 {
        return Err(format!(
            "握手已完成，但配对文件 {out_path} 为空"
        ));
    }
    tracing::info!("RPPairing：配对文件已写入 {out_path}（{size} 字节）");

    Ok((
        peer_info.name,
        peer_info.model,
        peer_info.remotepairing_udid,
        out_path,
        bytes_to_hex(&host_alt_irk),
    ))
}

// ---------------------------------------------------------------------------
// Free

/// # Safety
/// `r` must be null or a `ALPairResult` populated by `run_host`.
pub unsafe fn result_free(r: *mut ALPairResult) {
    if r.is_null() {
        return;
    }
    for p in [
        (*r).error,
        (*r).device_name,
        (*r).device_model,
        (*r).device_udid,
        (*r).pairing_file_path,
        (*r).host_alt_irk_hex,
    ] {
        if !p.is_null() {
            drop(CString::from_raw(p));
        }
    }
    *r = ALPairResult::empty();
}

// ---------------------------------------------------------------------------
// Helpers

fn emit_ready(cbs: &Cbs, service_id: &str, port: u16, host_info: &PairableHostInfo) {
    let Some(cb) = cbs.ready else { return };
    let records = host_info.mdns_txt_records(service_id);
    let keys: Vec<CString> = records
        .iter()
        .map(|(k, _)| CString::new(k.as_str()).unwrap_or_default())
        .collect();
    let vals: Vec<CString> = records
        .iter()
        .map(|(_, v)| CString::new(v.as_str()).unwrap_or_default())
        .collect();
    let key_ptrs: Vec<*const c_char> = keys.iter().map(|s| s.as_ptr()).collect();
    let val_ptrs: Vec<*const c_char> = vals.iter().map(|s| s.as_ptr()).collect();

    let Ok(id_c) = CString::new(service_id) else { return };
    cb(
        cbs.ctx,
        id_c.as_ptr(),
        port,
        key_ptrs.as_ptr(),
        val_ptrs.as_ptr(),
        records.len(),
    );
}

fn parse_alt_irk(s: &str) -> Option<[u8; 16]> {
    if s.len() != 32 { return None; }
    let mut out = [0u8; 16];
    for (i, b) in out.iter_mut().enumerate() {
        *b = u8::from_str_radix(s.get(i * 2..i * 2 + 2)?, 16).ok()?;
    }
    Some(out)
}

fn bytes_to_hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}
