import Foundation
import AirliftFFI

/// 驱动 RPPairing 主机：申请本地网络权限，在用户于设置中确认配对码期间保持 App 存活，
/// 通过 Bonjour 广播配对服务，
/// 并在非主线程上运行 `al_pairing_run_host`。
@MainActor
final class PairingController: ObservableObject {

    static let shared = PairingController()

    private let hostName = "AirCard-iOS"
    private let hostModel = "Mac17,7"   // 让设备端看到一个类似 Mac 的配对方
    private let bindAddress = "0.0.0.0"

    private var netService: NetService?
    private let localNetwork = LocalNetworkAuthorization()
    private let keepAlive = KeepAlive()

    @Published private(set) var running = false
    @Published var pairingStatus: String = "idle"
    @Published var pairingPIN: String? = nil

    /// 当前找到或生成的配对文件路径。
    static var customPairingFilePath: String? = nil

    /// 持久化的 altIRK 用于跨多次配对保持主机身份稳定，
    /// 使已配对过的设备能够识别该主机。
    private static let altIRKKey = "aircardPairingHostAltIRK"
    nonisolated private static var storedAltIRK: String {
        get { UserDefaults.standard.string(forKey: altIRKKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: altIRKKey) }
    }

    private var pairContinuation: CheckedContinuation<String, Error>?

    // MARK: - Public API

    enum PairingError: LocalizedError {
        case busy
        case localNetworkDenied
        case zeroBytes
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .busy: return "配对正在进行中。"
            case .localNetworkDenied: return "本地网络权限已关闭，请在「设置 › AirCard-iOS › 本地网络」中开启。"
            case .zeroBytes: return "配对生成的文件为空。请先同意配对请求，然后重试。"
            case let .failed(msg): return msg
            }
        }
    }

    /// 确保给定配对文件被同步为标准的 aircard_pairing.plist 与 airlift_pairing.plist。
    @discardableResult
    static func syncCanonicalPairingFile(from sourcePath: String) -> String {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let aircardURL = dir.appendingPathComponent("aircard_pairing.plist")
        let airliftURL = dir.appendingPathComponent("airlift_pairing.plist")

        if let data = try? Data(contentsOf: URL(fileURLWithPath: sourcePath)), !data.isEmpty {
            if sourcePath != aircardURL.path {
                try? data.write(to: aircardURL, options: .atomic)
            }
            if sourcePath != airliftURL.path {
                try? data.write(to: airliftURL, options: .atomic)
            }
            customPairingFilePath = aircardURL.path
            return aircardURL.path
        }
        return sourcePath
    }

    /// 配对文件的写入或读取路径。
    /// 依次检查标准 aircard_pairing.plist、自定义路径，或 Documents 中的任意 plist，
    /// 并自动采纳、标准化。
    static func pairingFilePath() -> String {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let aircardPath = dir.appendingPathComponent("aircard_pairing.plist").path
        if FileManager.default.fileExists(atPath: aircardPath) {
            let size = (try? FileManager.default.attributesOfItem(atPath: aircardPath)[.size] as? Int) ?? 0
            if size > 0 { return aircardPath }
        }

        let airliftPath = dir.appendingPathComponent("airlift_pairing.plist").path
        if FileManager.default.fileExists(atPath: airliftPath) {
            let size = (try? FileManager.default.attributesOfItem(atPath: airliftPath)[.size] as? Int) ?? 0
            if size > 0 {
                _ = syncCanonicalPairingFile(from: airliftPath)
                return aircardPath
            }
        }

        if let custom = customPairingFilePath, FileManager.default.fileExists(atPath: custom) {
            let size = (try? FileManager.default.attributesOfItem(atPath: custom)[.size] as? Int) ?? 0
            if size > 0 {
                _ = syncCanonicalPairingFile(from: custom)
                return aircardPath
            }
        }

        // 扫描 Documents 目录中的任意 .plist 文件
        if let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            let plists = files.filter {
                $0.hasSuffix(".plist") || $0.hasSuffix(".mobiledevicepairing") || $0.hasSuffix(".mobilepair")
            }
            for candidate in plists {
                let candidatePath = dir.appendingPathComponent(candidate).path
                let size = (try? FileManager.default.attributesOfItem(atPath: candidatePath)[.size] as? Int) ?? 0
                if size > 0 {
                    _ = syncCanonicalPairingFile(from: candidatePath)
                    return aircardPath
                }
            }
        }

        return aircardPath
    }

    /// 启动配对主机，成功时返回配对文件路径，失败时抛出错误。
    func startAndWait() async throws -> String {
        // 若已在运行，先取消上一次，以便干净地重新启动
        if running {
            softCancel()
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return try await withCheckedThrowingContinuation { cont in
            pairContinuation = cont
            start()
        }
    }

    func softCancel() {
        stopAdvertising()
        keepAlive.stopAll()
        running = false
        pairingPIN = nil
        pairingStatus = "已取消"
        resolve(.failure(CancellationError()))
    }

    private func resolve(_ result: Result<String, Error>) {
        guard let cont = pairContinuation else { return }
        pairContinuation = nil
        cont.resume(with: result)
    }

    func start() {
        stopAdvertising()
        keepAlive.stopAll()
        running = true
        pairingPIN = nil
        pairingStatus = "正在启动本机配对服务…"

        Task {
            _ = await localNetwork.request()
            guard running else { return }

            keepAlive.startAudio()
            pairingStatus = "正在广播… 请打开「设置」完成配对"
            runHost()
        }
    }

    // MARK: - 内部实现

    private func runHost() {
        let bind = bindAddress
        let name = hostName
        let model = hostModel
        let outPath = Self.pairingFilePath()
        let altIRK = Self.storedAltIRK
        nonisolated(unsafe) let ctx = UnsafeMutableRawPointer(
            Unmanaged.passRetained(self).toOpaque()
        )

        DispatchQueue.global(qos: .userInitiated).async {
            var result = ALPairResult()
            let rc = bind.withCString { bindC in
                name.withCString { nameC in
                    model.withCString { modelC in
                        outPath.withCString { outC in
                            altIRK.withCString { irkC in
                                al_pairing_run_host(
                                    bindC, 0, nameC, modelC, outC, irkC,
                                    pairReadyCallback, pairPinCallback, ctx, &result)
                            }
                        }
                    }
                }
            }

            let outcome: Outcome
            if rc == 0 {
                let issued = cStr(result.host_alt_irk_hex)
                if !issued.isEmpty { Self.storedAltIRK = issued }
                let devName = cStr(result.device_name)
                let filePath = cStr(result.pairing_file_path)
                outcome = .success(
                    name: devName.isEmpty ? "iPhone" : devName,
                    path: filePath.isEmpty ? outPath : filePath
                )
            } else {
                let msg = cStr(result.error)
                outcome = .failure(msg.isEmpty ? "pairing failed (rc=\(rc))" : msg)
            }
            al_pairing_result_free(&result)

            DispatchQueue.main.async {
                Unmanaged<PairingController>.fromOpaque(ctx).release()
                self.finish(outcome)
            }
        }
    }

    private enum Outcome {
        case success(name: String, path: String)
        case failure(String)
    }

    private func finish(_ outcome: Outcome) {
        stopAdvertising()
        // 后台保活 5 秒，避免用户从「设置」返回前 App 被系统杀掉
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.keepAlive.stopAll()
        }
        running = false
        pairingPIN = nil

        switch outcome {
        case let .success(name, path):
            let canonical = Self.syncCanonicalPairingFile(from: path)
            let size = (try? FileManager.default.attributesOfItem(atPath: canonical)[.size] as? Int) ?? 0
            if size == 0 {
                pairingStatus = "失败：配对文件为空"
                resolve(.failure(PairingError.zeroBytes))
            } else {
                pairingStatus = "已配对：\(name)（\(size) 字节）"
                resolve(.success(canonical))
            }
        case let .failure(message):
            pairingStatus = "失败：\(message)"
            resolve(.failure(PairingError.failed(message)))
        }
    }


    // MARK: Bonjour 广播

    fileprivate func startAdvertising(serviceID: String, port: Int32, txt: [String: Data]) {
        stopAdvertising()
        let service = NetService(
            domain: "",
            type: "_remotepairing-pairable-host._tcp.",
            name: serviceID,
            port: port
        )
        service.setTXTRecord(NetService.data(fromTXTRecord: txt))
        service.publish()
        netService = service
        pairingStatus = "正在广播——请打开「设置 › 隐私与安全性 › 开发者模式」"
    }

    fileprivate func presentPin(_ pin: String) {
        pairingPIN = pin
        pairingStatus = "请在「设置 › 隐私与安全性 › 开发者模式 › 与 AirCard-iOS 配对」中输入配对码 \(pin)"
    }

    private func stopAdvertising() {
        netService?.stop()
        netService = nil
    }
}

// MARK: - C 回调函数

private let pairReadyCallback: ALPairReadyCb = { ctx, serviceID, port, keys, vals, count in
    guard let ctx = ctx, let serviceID = serviceID else { return }
    let controller = Unmanaged<PairingController>.fromOpaque(ctx).takeUnretainedValue()
    let id = String(cString: serviceID)

    var txt: [String: Data] = [:]
    if let keys = keys, let vals = vals {
        for i in 0..<Int(count) {
            guard let k = keys[i], let v = vals[i] else { continue }
            txt[String(cString: k)] = Data(String(cString: v).utf8)
        }
    }
    DispatchQueue.main.async {
        controller.startAdvertising(serviceID: id, port: Int32(port), txt: txt)
    }
}

private let pairPinCallback: ALPairPinCb = { pin, ctx in
    guard let ctx = ctx, let pin = pin else { return }
    let controller = Unmanaged<PairingController>.fromOpaque(ctx).takeUnretainedValue()
    let pinString = String(cString: pin)
    DispatchQueue.main.async {
        controller.presentPin(pinString)
    }
}

private func cStr(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
    guard let ptr = ptr else { return "" }
    return String(cString: ptr)
}

