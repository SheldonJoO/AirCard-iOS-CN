import Foundation
import AVFAudio
import CoreLocation
import Network

// MARK: - 后台保活（音频 + 可选定位）

/// 在用户于设置中确认配对码期间，保持 App 在后台运行，
/// 路径为「设置 → 开发者模式」。
@MainActor
final class KeepAlive: NSObject {

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var audioRunning = false

    func startAudio() {
        guard !audioRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            if player.engine == nil {
                engine.attach(player)
            }
            let format = engine.outputNode.inputFormat(forBus: 0)
            guard format.sampleRate > 0 && format.channelCount > 0 else {
                audioRunning = true
                return
            }

            engine.connect(player, to: engine.mainMixerNode, format: format)

            let frames = max(1024, AVAudioFrameCount(format.sampleRate))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
                audioRunning = true
                return
            }
            buffer.frameLength = frames
            if let channelData = buffer.floatChannelData {
                for ch in 0..<Int(format.channelCount) {
                    memset(channelData[ch], 0, Int(frames) * MemoryLayout<Float>.size)
                }
            }

            if !engine.isRunning {
                try engine.start()
            }
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            audioRunning = true
        } catch {
            audioRunning = false
        }
    }

    func stopAudio() {
        guard audioRunning else { return }
        audioRunning = false
        player.stop()
        if engine.isRunning {
            engine.stop()
        }
        if player.engine != nil {
            engine.detach(player)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func stopAll() {
        stopAudio()
    }
}

// MARK: - 本地网络权限

/// 通过短暂广播并搜索一个一次性的 Bonjour 服务，触发本地网络权限弹窗。
/// 采用非阻塞方式并设置较短超时，
/// 因此不会卡住配对流程。
@MainActor
final class LocalNetworkAuthorization {
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var continuation: CheckedContinuation<Bool, Never>?

    // 必须与 Info.plist 中 NSBonjourServices 的某一项一致。
    private let probeType = "_aircardprobe._tcp"

    func request(timeout: TimeInterval = 1.5) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            self.continuation = cont

            let params = NWParameters.tcp
            params.includePeerToPeer = true

            let listener = try? NWListener(using: params)
            listener?.service = NWListener.Service(name: "AirCardProbe", type: probeType)
            listener?.newConnectionHandler = { $0.cancel() }
            listener?.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    MainActor.assumeIsolated { self?.finish(true) }
                }
            }
            self.listener = listener

            let browser = NWBrowser(for: .bonjour(type: probeType, domain: nil), using: params)
            browser.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    MainActor.assumeIsolated { self?.finish(true) }
                }
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                if !results.isEmpty {
                    MainActor.assumeIsolated { self?.finish(true) }
                }
            }
            self.browser = browser

            listener?.start(queue: .main)
            browser.start(queue: .main)

            // 短超时 —— 若弹窗此前已允许或已忽略，则直接继续。
            // 如有需要，PairingController 中的 NetService.publish() 同样会触发权限申请。
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                MainActor.assumeIsolated { self?.finish(true) }
            }
        }
    }

    private func finish(_ authorized: Bool) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: authorized)
        browser?.cancel(); browser = nil
        listener?.cancel(); listener = nil
    }
}
