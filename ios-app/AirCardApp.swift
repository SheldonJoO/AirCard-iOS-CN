import SwiftUI
import AirliftFFI

@main
struct AirCardApp: App {
    @StateObject private var vm = AppViewModel()

    init() {
        // 将 Rust tracing / idevice 日志接入 App 的 vm 日志数组。
        al_log_init({ _, msg in
            guard let msg = msg else { return }
            let line = String(cString: msg)
            DispatchQueue.main.async {
                AppViewModel.sharedLogSink?(line)
            }
        }, nil)

        // vm 创建完成后把接收器指向它（在 AppViewModel.init 中设置）。
        // 确保 ALGetGrappaToken 符号被保留并链接进最终二进制
        _ = ALGetGrappaToken(0, 0, 0, nil, 0, nil, nil, 0)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
        }
    }
}

@_silgen_name("ALGetGrappaToken")
func ALGetGrappaToken(
    _ inVersion: UInt32,
    _ inDeviceType: UInt32,
    _ inProtocolVersion: UInt32,
    _ outBuf: UnsafeMutablePointer<UInt8>?,
    _ maxLen: Int,
    _ outLen: UnsafeMutablePointer<Int>?,
    _ errBuf: UnsafeMutablePointer<CChar>?,
    _ errLen: Int
) -> Int32

