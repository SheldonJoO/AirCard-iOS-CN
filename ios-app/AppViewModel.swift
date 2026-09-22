import Foundation
import UIKit
import SwiftUI
import AirliftFFI

// MARK: - AppViewModel

@MainActor
final class AppViewModel: ObservableObject {

    /// Rust 日志的静态接收器 —— 在 init 中设置，供 AirliftApp 转发日志。
    static var sharedLogSink: ((String) -> Void)? = nil
    static weak var shared: AppViewModel? = nil

    // MARK: - 配对
    @Published var pairingStatus: String = ""
    @Published var pairingPIN: String? = nil
    @Published var hasPairingFile: Bool = false
    @Published var pairingFileName: String = ""
    @Published var pairingPhase: PairingPhase = .idle
    @Published var documentsPlistFiles: [String] = []

    enum PairingPhase: Equatable {
        case idle, pairing
    }

    // MARK: - VPN / 网络
    @Published var vpnUp: Bool = false
    @Published var wifiUp: Bool = false
    @Published var networkDetail: String = ""
    @Published var deviceIP: String = "10.7.0.1"   // LocalDevVPN default peer

    // MARK: - 标签页
    @Published var selectedTab: AppTab = .pairing

    // MARK: - 钱包卡片标签页
    @Published var cards: [CardItem] = []
    @Published var cardFlashPhase: FlashPhase = .idle
    @Published var cardFlashProgress: Double = 0
    @Published var cardFlashLog: [String] = []

    enum FlashPhase: Equatable {
        case idle, running, done(ok: Bool)
    }

    // MARK: - 密码盘主题标签页
    @Published var passcodeMode: CreatorMode = .applyTheme
    @Published var loadedTheme: PasscodeThemeInfo? = nil
    @Published var documentsThemes: [String] = []
    @Published var sliceMode: SliceMode = .posterSlice

    // 海报切图
    @Published var posterImage: UIImage? = nil
    @Published var posterZoom: CGFloat = 1.0
    @Published var posterOffset: CGPoint = .zero
    @Published var maskToCircles: Bool = false
    @Published var slicedKeys: [String: UIImage] = [:]

    // 单个按键
    @Published var customKeys: [String: UIImage] = [:]
    @Published var rawIndividualImages: [String: UIImage] = [:]
    @Published var individualOffsets: [String: CGPoint] = [:]
    @Published var individualZooms: [String: CGFloat] = [:]
    @Published var selectedKeyDigit: String? = nil

    @Published var passthmFlashPhase: FlashPhase = .idle
    @Published var passthmFlashProgress: Double = 0
    @Published var passthmFlashLog: [String] = []

    // MARK: - Tendies / 壁纸标签页
    @Published var tendieItems: [TendieItem] = []
    @Published var posterBoardContainer: String = ""
    @Published var isDetectingContainer: Bool = false
    @Published var resetPBProtections: Bool = true
    @Published var tendiesFlashPhase: FlashPhase = .idle
    @Published var tendiesFlashProgress: Double = 0
    @Published var tendiesFlashLog: [String] = []
    @Published var isNeoSpringing: Bool = false

    // MARK: - AirCard 界面状态与属性
    static var detectedDeviceLanguage: PasscodeLanguageTarget {
        let code = Locale.preferredLanguages.first?.components(separatedBy: "-").first?.lowercased() ?? "en"
        for target in PasscodeLanguageTarget.allCases {
            if target.code == code {
                return target
            }
        }
        return .en
    }

    @Published var targetTelephonyVersion: String = "TelephonyUI-10"
    @Published var passcodeLanguageTarget: PasscodeLanguageTarget = AppViewModel.detectedDeviceLanguage
    @Published var passcodeBoldTarget: PasscodeBoldTarget = .both
    @Published var showSuccessAlert: Bool = false
    @Published var successAlertMessage: String = ""
    @Published var exportedThemeURL: URL? = nil
    @Published var showShareSheet: Bool = false

    // MARK: - 通用状态
    @Published var errorMessage: String? = nil
    @Published var log: [String] = []
    @Published var showDeletePairingConfirm: Bool = false

    private let storageKeys = [
        "aircard.cards",
        "aircard-ios.cards",
        "airlift.cards",
        "mak5er.savedCards",
        "LumiCards.savedCards",
        "savedCards"
    ]

    init() {
        Self.shared = self
        refreshPairingFile()
        loadSavedCards()
        refreshNetworkStatus()
        scanDocumentsDirectory()
        posterBoardContainer = UserDefaults.standard.string(forKey: "aircard.posterboard_container") ?? ""
        loadSavedTendies()

        // 把 Rust 日志输出接入到本类的日志数组中。
        AppViewModel.sharedLogSink = { [weak self] line in
            self?.log.append(line)
        }
    }

    // MARK: - 文档目录扫描

    /// 扫描 App 的 Documents 文件夹（在「文件」App 中对应「我的 iPhone › Airlift」）
    /// 查找用户放入的配对 plist 或 .passthm 主题文件。
    func scanDocumentsDirectory() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: docs.path) else { return }

        // 查找 plist 文件
        documentsPlistFiles = items.filter {
            $0.hasSuffix(".plist") || $0.hasSuffix(".mobiledevicepairing") || $0.hasSuffix(".mobilepair")
        }.sorted()

        // 查找 .passthm 主题
        documentsThemes = items.filter { $0.hasSuffix(".passthm") }.sorted()

        // 自动发现放入 Documents 或 Documents/Tendies 的 .tendies 文件
        scanDocumentsForTendies()
    }

    func scanDocumentsForTendies() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tendiesDir = TendiesEngine.tendiesStorageDirectory
        
        var foundURLs: [URL] = []
        if let rootItems = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
            for u in rootItems where u.pathExtension.lowercased() == "tendies" {
                let target = tendiesDir.appendingPathComponent(u.lastPathComponent)
                if u.path != target.path && !FileManager.default.fileExists(atPath: target.path) {
                    try? FileManager.default.copyItem(at: u, to: target)
                }
                foundURLs.append(target)
            }
        }
        if let storedItems = try? FileManager.default.contentsOfDirectory(at: tendiesDir, includingPropertiesForKeys: nil) {
            for u in storedItems where u.pathExtension.lowercased() == "tendies" {
                if !foundURLs.contains(u) {
                    foundURLs.append(u)
                }
            }
        }

        let newURLs = foundURLs.filter { url in
            !tendieItems.contains(where: { $0.fileName == url.lastPathComponent })
        }

        guard !newURLs.isEmpty else { return }

        Task {
            await self.importTendieFiles(urls: newURLs)
        }
    }

    @discardableResult
    func importPairingFile(from sourceURL: URL, originalName: String? = nil) -> Bool {
        let isSecured = sourceURL.startAccessingSecurityScopedResource()
        defer { if isSecured { sourceURL.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: sourceURL), !data.isEmpty else {
            return false
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let aircardURL = docs.appendingPathComponent("aircard_pairing.plist")
        let airliftURL = docs.appendingPathComponent("airlift_pairing.plist")

        do {
            try data.write(to: aircardURL, options: .atomic)
            try data.write(to: airliftURL, options: .atomic)

            if let orig = originalName, !orig.isEmpty,
               orig != "aircard_pairing.plist" && orig != "airlift_pairing.plist" {
                let origURL = docs.appendingPathComponent(orig)
                try? data.write(to: origURL, options: .atomic)
            }

            PairingController.customPairingFilePath = aircardURL.path
            refreshPairingFile()
            pairingStatus = "配对文件已载入 ✅（\(originalName ?? "aircard_pairing.plist")）"
            return true
        } catch {
            errorMessage = "保存配对文件失败：\(error.localizedDescription)"
            return false
        }
    }

    func selectPairingFile(filename: String) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = docs.appendingPathComponent(filename).path
        let canonical = PairingController.syncCanonicalPairingFile(from: path)
        let exists = FileManager.default.fileExists(atPath: canonical)
        hasPairingFile = exists
        pairingFileName = exists ? (canonical as NSString).lastPathComponent : ""
        scanDocumentsDirectory()
    }

    // MARK: - 配对文件

    func refreshPairingFile() {
        let path = PairingController.pairingFilePath()
        let exists = FileManager.default.fileExists(atPath: path)
        hasPairingFile = exists
        pairingFileName = exists ? (path as NSString).lastPathComponent : ""
        scanDocumentsDirectory()
    }


    var pairingFileSizeString: String {
        let path = PairingController.pairingFilePath()
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func startPairing() {
        pairingPhase = .pairing
        pairingPIN = nil
        pairingStatus = "正在启动本机配对服务…"
        errorMessage = nil

        let ctrl = PairingController.shared

        Task {
            do {
                let path = try await ctrl.startAndWait()
                await MainActor.run {
                    self.pairingPhase = .idle
                    self.refreshPairingFile()
                    self.pairingStatus = "配对成功！✅"
                    self.log.append("配对完成：\(path)")
                }
            } catch is CancellationError {
                self.pairingPhase = .idle
                self.pairingStatus = "已取消。"
            } catch {
                self.pairingPhase = .idle
                self.pairingStatus = ""
                self.errorMessage = "配对失败：\(error.localizedDescription)"
            }
        }

        // Poll PairingController status every 0.2s while pairing
        Task {
            while pairingPhase == .pairing {
                try? await Task.sleep(nanoseconds: 200_000_000)
                await MainActor.run {
                    guard self.pairingPhase == .pairing else { return }
                    self.pairingStatus = ctrl.pairingStatus
                    self.pairingPIN   = ctrl.pairingPIN
                }
            }
        }
    }

    func cancelPairing() {
        PairingController.shared.softCancel()
        pairingPhase = .idle
        pairingStatus = ""
    }

    func deletePairingFile() {
        let path = PairingController.pairingFilePath()
        try? FileManager.default.removeItem(atPath: path)
        PairingController.customPairingFilePath = nil
        refreshPairingFile()
        pairingStatus = "配对文件已删除"
    }

    // MARK: - 网络

    func refreshNetworkStatus() {
        let ip = deviceIP
        let (vpn, wifi, detail) = NetworkStatus.summarize(deviceIP: ip)
        vpnUp = vpn
        wifiUp = wifi
        networkDetail = detail
    }

    // MARK: - 卡片管理与实时扫描

    @Published var isScanningCards: Bool = false
    @Published var scanStatusText: String = ""
    private var stopScanningFlag = false

    nonisolated static let cardRegexes: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: "/(?:Cards|Passes/Cards)/([-A-Za-z0-9_+=]{20,44})(?:\\.pkpass|\\.cache|\\.pkcache|/|\\s|\"|'|\\)|,|$)"),
        try! NSRegularExpression(pattern: "/([-A-Za-z0-9_+=]{20,44})\\.(?:pkpass|cache|pkcache)"),
        try! NSRegularExpression(pattern: "(?<![A-Za-z0-9+/_-])([A-Za-z0-9+/_-]{27}=)(?![A-Za-z0-9+/_-])"),
        try! NSRegularExpression(pattern: #"PDCardFileManager: writing card\s+([A-Za-z0-9+/_-]+={0,2})(?=\s|\)|,|$)"#),
        try! NSRegularExpression(pattern: #"PDPassLibrary: wrote pass\s+([A-Za-z0-9+/_-]+={0,2})(?=\s|\)|,|$)"#),
        try! NSRegularExpression(pattern: #"VerificationCheck\.([A-Za-z0-9+/_-]+={0,2})(?=\s|\)|,|$)"#)
    ]


    func toggleCardScanning() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            if isScanningCards {
                stopCardScanning()
            } else {
                startCardScanning()
            }
        }
    }

    private static let dummyCardHashes: Set<String> = [
        "OM6NYhwXMZrAw0sRUjR62wmF4ZQ=",
        "M6nDwZrkYbFlsodLgCbvyFZQ1cc=",
        "kJL-D0rr-SZhbj2c8nK-OQ9hCMY=",
        "hwAtAmHKYwsQrJbT5cTNDsaxVME="
    ]

    func startCardScanning() {
        guard !isScanningCards else { return }
        guard hasPairingFile else {
            errorMessage = "扫描前需要先有配对文件。请先配对本机，或选择一个 .plist 文件。"
            return
        }

        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            isScanningCards = true
            scanStatusText = "请打开 Apple Pay（双击侧边按钮）并轻点你的卡片…"
        }
        log.append("已启动实时卡片扫描…")

        let pairingPath = PairingController.pairingFilePath()

        let thread = Thread {
            var outError: UnsafeMutablePointer<CChar>? = nil

            let rc = pairingPath.withCString { pairC in
                al_syslog_stream_start(
                    pairC,
                    { _, line in
                        guard let line = line else { return }
                        let lineStr = String(cString: line)
                        let lower = lineStr.lowercased()
                        // 在后台线程预过滤，避免主线程 runloop 被日志淹没
                        if lower.contains("pass") ||
                           lower.contains("card") ||
                           lower.contains("stockholm") ||
                           lower.contains("wallet") ||
                           lower.contains("nanopass") ||
                           lower.contains("verificationcheck") {
                            DispatchQueue.main.async {
                                AppViewModel.shared?.processSyslogLine(lineStr)
                            }
                        }
                    },
                    nil,
                    &outError
                )
            }

            let errStr = outError.flatMap { String(validatingUTF8: $0) }
            if let p = outError { al_string_free(p) }

            DispatchQueue.main.async {
                guard let vm = AppViewModel.shared else { return }
                vm.isScanningCards = false
                if rc != 0 {
                    let msg = errStr ?? "rc=\(rc)"
                    vm.scanStatusText = "扫描已停止：\(msg)"
                    vm.log.append("❌ 扫描器错误：\(msg)")
                    vm.errorMessage = "卡片扫描器错误：\(msg)"
                } else {
                    vm.scanStatusText = "扫描已停止，共 \(vm.cards.count) 张卡片。"
                    vm.log.append("扫描已停止，共 \(vm.cards.count) 张卡片。")
                }
            }
        }
        thread.name = "AirCard.SyslogScanner"
        thread.stackSize = 4 * 1024 * 1024 // 4 MB stack
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    func stopCardScanning() {
        al_syslog_stream_stop()
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            isScanningCards = false
            scanStatusText = "扫描已停止，共 \(cards.count) 张卡片。"
        }
        saveCards()
    }

    func processSyslogLine(_ line: String) {
        let lower = line.lowercased()
        let isWalletSubsystem = lower.contains("passd") ||
                                lower.contains("passbook") ||
                                lower.contains("passkit") ||
                                lower.contains("stockholm") ||
                                lower.contains("nanopassd") ||
                                lower.contains("wallet") ||
                                lower.contains("pdcardfilemanager") ||
                                lower.contains("pdpasslibrary") ||
                                lower.contains("verificationcheck") ||
                                lower.contains("/cards/")

        guard isWalletSubsystem else { return }

        let isWalletContext = lower.contains("card") ||
                              lower.contains("pass") ||
                              lower.contains("payment") ||
                              lower.contains("pkpass") ||
                              lower.contains("uniqueid") ||
                              lower.contains("identifier") ||
                              lower.contains("face") ||
                              lower.contains("cache") ||
                              lower.contains("stockholm") ||
                              lower.contains("pdcardfilemanager") ||
                              lower.contains("pdpasslibrary") ||
                              lower.contains("verificationcheck") ||
                              lower.contains("/cards/")

        guard isWalletContext else { return }

        for regex in Self.cardRegexes {
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            for m in matches {
                if m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: line) {
                    let candidateRaw = String(line[r])
                    guard let candidate = CardItem.cleanCardId(candidateRaw) else { continue }
                    if Self.dummyCardHashes.contains(candidate) { continue }
                    if !self.cards.contains(where: { $0.id == candidate }) {
                        self.cards.append(CardItem(id: candidate, isSelected: true))
                        self.saveCards()
                        self.scanStatusText = "发现卡片：\(candidate)"
                        self.log.append("发现卡片：\(candidate)")
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                }
            }
        }
    }

    nonisolated static func cardImagePath(for cardId: String) -> URL {
        let safeId = cardId.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-")
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cardsDir = docDir.appendingPathComponent("WalletCards", isDirectory: true)
        if !FileManager.default.fileExists(atPath: cardsDir.path) {
            try? FileManager.default.createDirectory(at: cardsDir, withIntermediateDirectories: true)
        }
        return cardsDir.appendingPathComponent("card_\(safeId).png")
    }

    func loadSavedCards() {
        var foundHashes: [String] = []
        for key in storageKeys {
            if let saved = UserDefaults.standard.stringArray(forKey: key), !saved.isEmpty {
                foundHashes = saved
                break
            }
        }
        var unique: [String] = []
        for raw in foundHashes {
            if let clean = CardItem.cleanCardId(raw), !unique.contains(clean) {
                unique.append(clean)
            }
        }
        cards = unique.filter { !Self.dummyCardHashes.contains($0) }.map { id in
            let path = Self.cardImagePath(for: id)
            let data = try? Data(contentsOf: path)
            // 使用降采样缩略图以压低内存占用，避免被 Jetsam 杀掉
            let img = data.flatMap { ImageEngine.safeImageFromData($0, maxDimension: 512) }
            return CardItem(id: id, customImageData: data, customImage: img)
        }
    }

    func clearAllCards() {
        for card in cards {
            let path = Self.cardImagePath(for: card.id)
            try? FileManager.default.removeItem(at: path)
        }
        cards.removeAll()
        saveCards()
    }

    func saveCards() {
        let hashes = cards.map(\.id)
        UserDefaults.standard.set(hashes, forKey: "aircard.cards")
        UserDefaults.standard.set(hashes, forKey: "airlift.cards")
        UserDefaults.standard.set(hashes, forKey: "mak5er.savedCards")
    }

    func setSkinForAllCards(image: UIImage) {
        for card in cards where card.isSelected {
            setCardImage(for: card.id, image: image)
        }
    }

    func selectAllCards(_ selected: Bool) {
        guard !cards.isEmpty else { return }
        cards = cards.map {
            var c = $0
            c.isSelected = selected
            return c
        }
    }

    func addCardHash(_ raw: String) {
        let parts = raw.components(separatedBy: CharacterSet(charactersIn: " \n\r\t,;"))
        var added = 0
        for p in parts {
            if let clean = CardItem.cleanCardId(p),
               !cards.contains(where: { $0.id == clean }) {
                cards.append(CardItem(id: clean))
                added += 1
            }
        }
        if added > 0 { saveCards() }
    }

    func setCardSelected(id: String, selected: Bool) {
        if let idx = cards.firstIndex(where: { $0.id == id }) {
            cards[idx].isSelected = selected
        }
    }

    func deleteCard(id: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            cards.removeAll { $0.id == id }
        }
        saveCards()
        let path = Self.cardImagePath(for: id)
        try? FileManager.default.removeItem(at: path)
    }

    func clearCardImage(for cardId: String) {
        if let idx = cards.firstIndex(where: { $0.id == cardId }) {
            cards[idx].customImage = nil
            cards[idx].customImageData = nil
        }
        let path = Self.cardImagePath(for: cardId)
        try? FileManager.default.removeItem(at: path)
    }

    func setCardImage(for cardId: String, image: UIImage) {
        guard let idx = cards.firstIndex(where: { $0.id == cardId }) else { return }
        // 内存中只保留轻量缩略图，保证界面流畅并防止 OOM
        let thumb = ImageEngine.normalizeAndDownsample(image, maxDimension: 512)
        cards[idx].customImage = thumb

        let actualId = cards[idx].id
        let path = Self.cardImagePath(for: actualId)
        // 在后台异步生成全分辨率 PNG 数据
        Task.detached(priority: .userInitiated) {
            let data = ImageEngine.prepareCardImage(from: image)
            if let data = data {
                try? data.write(to: path)
            }
            await MainActor.run {
                if let i = AppViewModel.shared?.cards.firstIndex(where: { $0.id == actualId }) {
                    AppViewModel.shared?.cards[i].customImageData = data
                }
            }
        }
    }

    // MARK: - 卡片刷入（通过 Airlift 漏洞利用）

    var canFlashCards: Bool {
        hasPairingFile &&
        cardFlashPhase != .running &&
        cards.contains { $0.isSelected && ($0.customImage != nil || $0.customImageData != nil) }
    }

    func flashCards() {
        guard canFlashCards else { return }
        let selected = cards.filter { $0.isSelected && ($0.customImage != nil || $0.customImageData != nil) }
        guard !selected.isEmpty else { return }

        cardFlashPhase    = .running
        cardFlashProgress = 0
        cardFlashLog.removeAll()
        errorMessage = nil

        if !vpnUp {
            cardFlashLog.append("⚠️ 提示：未检测到回环 VPN，正在尝试直连回环地址（127.0.0.1）...")
        }

        let pairingPath = PairingController.pairingFilePath()

        Task.detached { [weak self] in
            guard let self = self else { return }
            let total = Double(selected.count)
            var successCount = 0
            for (i, card) in selected.enumerated() {
                let cleanId = CardItem.cleanCardId(card.id) ?? card.id
                let safeCardId = cleanId.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-")

                await MainActor.run {
                    self.cardFlashLog.append("[\(i+1)/\(selected.count)] 正在刷入卡片 \(cleanId.prefix(12))…")
                    self.cardFlashProgress = Double(i) / total
                }

                // 按需加载全分辨率源图，以节省内存
                let sourceImg: UIImage? = {
                    if let d = card.customImageData, let img = UIImage(data: d) { return img }
                    let p = Self.cardImagePath(for: cleanId)
                    if let d = try? Data(contentsOf: p), let img = UIImage(data: d) { return img }
                    return card.customImage
                }()

                guard let sourceImg = sourceImg else {
                    await MainActor.run { self.cardFlashLog.append("  ⚠️ 卡片 \(cleanId.prefix(8)) 没有设置图片") }
                    continue
                }

                // 1. 准备多分辨率卡面
                let allSkins = ImageEngine.prepareAllCardSkins(from: sourceImg)
                guard !allSkins.isEmpty else {
                    await MainActor.run { self.cardFlashLog.append("  ⚠️ 卡面图片生成失败") }
                    continue
                }

                let stageCardDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("airlift_card_\(safeCardId)_\(UUID().uuidString)")
                try? FileManager.default.createDirectory(at: stageCardDir, withIntermediateDirectories: true)

                for (name, data) in allSkins {
                    try? data.write(to: stageCardDir.appendingPathComponent(name))
                }

                let pkpassTarget = "/var/mobile/Library/Passes/Cards/\(cleanId).pkpass"

                await MainActor.run {
                    self.cardFlashLog.append("  ⚡ 正在注入卡面到 \(cleanId.prefix(10)).pkpass…")
                }

                var writeOk = false
                var errDesc: String? = nil
                await withCheckedContinuation { cont in
                    DispatchQueue.global(qos: .userInitiated).async {
                        var outError: UnsafeMutablePointer<CChar>? = nil
                        let rc = pairingPath.withCString { pairC in
                            stageCardDir.path.withCString { srcC in
                                pkpassTarget.withCString { tgtC in
                                    al_exploit_write_dir(pairC, srcC, tgtC, { _, msg in
                                        guard let msg = msg else { return }
                                        let line = String(cString: msg)
                                        DispatchQueue.main.async { AppViewModel.shared?.cardFlashLog.append("    " + line) }
                                    }, nil, &outError)
                                }
                            }
                        }
                        if let p = outError {
                            errDesc = String(validatingUTF8: p)
                            al_string_free(p)
                        }
                        writeOk = (rc == 0)
                        cont.resume()
                    }
                }

                try? FileManager.default.removeItem(at: stageCardDir)

                if !writeOk {
                    await MainActor.run {
                        self.cardFlashLog.append("  ❌ 卡面写入失败：\(errDesc ?? "漏洞利用错误")")
                    }
                    continue
                }

                await MainActor.run {
                    self.cardFlashLog.append("  ✅ 卡面已应用！正在使卡片缓存失效…")
                }

                // 2. 使缓存文件失效（尽力而为：部分 iOS 版本没有 .cache 或 .pkcache 文件夹）
                let stageInvDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("airlift_inv_\(UUID().uuidString)")
                try? FileManager.default.createDirectory(at: stageInvDir, withIntermediateDirectories: true)
                for leaf in ["FrontFace", "Preview", "PlaceHolder"] {
                    try? Data("corrupted".utf8).write(to: stageInvDir.appendingPathComponent(leaf))
                }

                for ext in [".cache", ".pkcache"] {
                    let cacheTarget = "/var/mobile/Library/Passes/Cards/\(cleanId)\(ext)"
                    await withCheckedContinuation { cont in
                        DispatchQueue.global(qos: .userInitiated).async {
                            var outError: UnsafeMutablePointer<CChar>? = nil
                            _ = pairingPath.withCString { pairC in
                                stageInvDir.path.withCString { srcC in
                                    cacheTarget.withCString { tgtC in
                                        al_exploit_write_dir(pairC, srcC, tgtC, nil, nil, &outError)
                                    }
                                }
                            }
                            if let p = outError { al_string_free(p) }
                            cont.resume()
                        }
                    }
                }
                try? FileManager.default.removeItem(at: stageInvDir)

                successCount += 1
                await MainActor.run {
                    self.cardFlashLog.append("  ✅ 卡片缓存已失效")
                    self.cardFlashProgress = Double(i + 1) / total
                }
            }

            await MainActor.run {
                if successCount > 0 {
                    self.cardFlashPhase = .done(ok: true)
                    self.cardFlashProgress = 1.0
                    self.cardFlashLog.append("🎉 已成功刷入 \(successCount)/\(selected.count) 张卡片！请强制关闭「钱包」App 后查看效果。")
                    self.successAlertMessage = "已成功为 \(successCount) 张卡片应用卡面！\n\n请强制关闭 iPhone 上的「钱包」App（或重启设备）后查看新卡面。")
                    self.showSuccessAlert = true
                } else {
                    self.cardFlashPhase = .done(ok: false)
                    self.cardFlashLog.append("❌ 卡片刷入失败，请检查连接后重试。")
                }
            }
        }
    }

    // MARK: - 海报切图

    var effectiveKeys: [String: UIImage] {
        sliceMode == .posterSlice ? slicedKeys : customKeys
    }

    func setPosterImage(_ img: UIImage) {
        posterImage = img
        posterZoom = 1.0
        posterOffset = .zero
        updatePosterSlicing()
    }

    func updatePosterSlicing() {
        guard let img = posterImage else { slicedKeys = [:]; return }
        slicedKeys = ImageEngine.slicePoster(
            image: img,
            zoom: posterZoom,
            offset: posterOffset,
            maskToCircles: maskToCircles
        )
    }

    func setIndividualKey(digit: String, image: UIImage) {
        rawIndividualImages[digit] = image
        individualOffsets[digit] = .zero
        individualZooms[digit] = 1.0
        selectedKeyDigit = digit
        updateIndividualKey(digit: digit)
    }

    func updateIndividualKey(digit: String) {
        guard let raw = rawIndividualImages[digit] else { return }
        let offset = individualOffsets[digit] ?? .zero
        let zoom   = individualZooms[digit] ?? 1.0
        if let cropped = ImageEngine.cropToCircle(
            image: raw,
            targetSize: CGSize(width: 225, height: 225),
            circleDiameter: 222.0,
            zoom: zoom,
            offset: offset
        ) {
            customKeys[digit] = cropped
        }
    }

    func clearIndividualKey(digit: String) {
        customKeys.removeValue(forKey: digit)
        rawIndividualImages.removeValue(forKey: digit)
        individualOffsets.removeValue(forKey: digit)
        individualZooms.removeValue(forKey: digit)
        if selectedKeyDigit == digit { selectedKeyDigit = nil }
    }

    func clearAllCreator() {
        posterImage = nil
        posterZoom = 1.0
        posterOffset = .zero
        slicedKeys.removeAll()
        customKeys.removeAll()
        rawIndividualImages.removeAll()
        individualOffsets.removeAll()
        individualZooms.removeAll()
        selectedKeyDigit = nil
    }

    // MARK: - 载入 .passthm

    func loadPassthm(url: URL) {
        Task.detached {
            let result = PasscodeThemeReader.inspect(url: url)
            await MainActor.run {
                if let (keys, rawData, count) = result {
                    self.loadedTheme = PasscodeThemeInfo(
                        name: url.deletingPathExtension().lastPathComponent,
                        filePath: url.path,
                        fileCount: count,
                        keysPreview: keys,
                        rawKeyData: rawData
                    )
                } else {
                    self.errorMessage = "读取 .passthm 失败——格式无效或不受支持。")
                }
            }
        }
    }

    func loadPassthmFromDocuments(filename: String) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(filename)
        loadPassthm(url: url)
    }

    func clearLoadedTheme() {
        loadedTheme = nil
        passthmFlashPhase = .idle
        passthmFlashProgress = 0
        passthmFlashLog.removeAll()
    }

    // MARK: - 刷入 .passthm

    var canFlashPassthm: Bool {
        guard hasPairingFile && passthmFlashPhase != .running else { return false }
        switch passcodeMode {
        case .applyTheme:
            return loadedTheme != nil && !(loadedTheme?.keysPreview.isEmpty ?? true)
        case .themeCreator:
            return !effectiveKeys.isEmpty
        }
    }

    func flashPassthm() {
        guard canFlashPassthm else { return }

        let isCreator = (passcodeMode == .themeCreator)
        let keys: [String: UIImage]
        let rawKeys: [String: Data]

        if isCreator {
            keys = effectiveKeys
            rawKeys = [:] // 重要：制作模式下绝不能使用之前载入的压缩包中的 rawKeyData！
        } else if let theme = loadedTheme {
            keys = theme.keysPreview
            rawKeys = theme.rawKeyData
        } else {
            return
        }

        guard !keys.isEmpty else {
            errorMessage = "没有载入任何按键图片。")
            return
        }

        passthmFlashPhase    = .running
        passthmFlashProgress = 0
        passthmFlashLog.removeAll()
        errorMessage = nil

        if !vpnUp {
            passthmFlashLog.append("⚠️ 提示：未检测到回环 VPN，正在尝试直连回环地址（127.0.0.1）...")
        }

        let pairingPath = PairingController.pairingFilePath()
        let targetVer = targetTelephonyVersion
        let targetLang = passcodeLanguageTarget
        let targetBold = passcodeBoldTarget
        let detected = AppViewModel.detectedDeviceLanguage.code

        Task.detached { [weak self] in
            guard let self = self else { return }

            let stageThemeDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("airlift_passthm_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: stageThemeDir, withIntermediateDirectories: true)

            let langs: [String]
            if targetLang == .all {
                langs = KeypadLocales.all
            } else {
                var l = [targetLang.code]
                if targetLang.code != "other" {
                    l.append("other")
                }
                if targetLang.code != detected && detected != "other" && !l.contains(detected) {
                    l.append(detected)
                }
                langs = l
            }
            let boldSuffixes: [String]
            switch targetBold {
            case .both: boldSuffixes = ["", "-bold"]
            case .boldOnly: boldSuffixes = ["-bold"]
            case .regularOnly: boldSuffixes = [""]
            }

            // 按配置生成所有语言与字重变体的键盘图片，并暂存到磁盘
            for (digit, image) in keys {
                let imgData: Data
                if let raw = rawKeys[digit] {
                    imgData = raw
                } else if let png = image.pngData() {
                    imgData = png
                } else {
                    continue
                }
                let stdSubtext = KeypadLayout.subtexts[digit] ?? ""

                for lang in langs {
                    for bld in boldSuffixes {
                        if digit == "0" {
                            // 空白变体：lang-0---white[-bold].png
                            try? imgData.write(to: stageThemeDir.appendingPathComponent("\(lang)-0---white\(bld).png"))
                            // 加号变体：lang-0-+--white[-bold].png
                            try? imgData.write(to: stageThemeDir.appendingPathComponent("\(lang)-0-+--white\(bld).png"))
                        } else if digit == "1" {
                            // Blank variant: lang-1---white[-bold].png
                            try? imgData.write(to: stageThemeDir.appendingPathComponent("\(lang)-1---white\(bld).png"))
                        } else {
                            // 1. 空白副标题
                            try? imgData.write(to: stageThemeDir.appendingPathComponent("\(lang)-\(digit)---white\(bld).png"))

                            // 2. 标准拉丁字母副标题
                            if !stdSubtext.isEmpty {
                                try? imgData.write(to: stageThemeDir.appendingPathComponent("\(lang)-\(digit)-\(stdSubtext)--white\(bld).png"))
                                let noSpace = stdSubtext.replacingOccurrences(of: " ", with: "")
                                if noSpace != stdSubtext {
                                    try? imgData.write(to: stageThemeDir.appendingPathComponent("\(lang)-\(digit)-\(noSpace)--white\(bld).png"))
                                }
                            }

                            // 3. 西里尔字母副标题
                            if (lang == "ru" || targetLang == .all), let ruSub = KeypadLocales.cyrillicRU[digit] {
                                try? imgData.write(to: stageThemeDir.appendingPathComponent("\(lang)-\(digit)-\(ruSub)--white\(bld).png"))
                            }
                            if (lang == "uk" || targetLang == .all), let ukSub = KeypadLocales.cyrillicUK[digit] {
                                try? imgData.write(to: stageThemeDir.appendingPathComponent("\(lang)-\(digit)-\(ukSub)--white\(bld).png"))
                            }
                        }
                    }
                }
            }

            // iOS TelephonyUI @3x 高清资源标记文件
            try? Data().write(to: stageThemeDir.appendingPathComponent("_big"))

            await MainActor.run {
                self.passthmFlashLog.append("⚡ 主题素材已就绪（\(targetVer) · \(langs.joined(separator: ", ").uppercased()) · \(targetBold.code)）。正在注入 iOS 缓存…")
                self.passthmFlashProgress = 0.2
            }

            let targetDirs: [String]
            if targetVer == "all" {
                targetDirs = [
                    "/var/mobile/Library/Caches/TelephonyUI-10",
                    "/var/mobile/Library/Caches/TelephonyUI-9",
                    "/var/mobile/Library/Caches/TelephonyUI-8"
                ]
            } else {
                targetDirs = [
                    "/var/mobile/Library/Caches/\(targetVer)"
                ]
            }

            var allOk = true
            var lastErr: String? = nil

            for (idx, targetPath) in targetDirs.enumerated() {
                let targetName = (targetPath as NSString).lastPathComponent
                await MainActor.run {
                    self.passthmFlashLog.append("  正在写入 \(targetName)…")
                }

                var stepOk = false
                await withCheckedContinuation { cont in
                    DispatchQueue.global(qos: .userInitiated).async {
                        var outError: UnsafeMutablePointer<CChar>? = nil
                        let rc = pairingPath.withCString { pairC in
                            stageThemeDir.path.withCString { srcC in
                                targetPath.withCString { tgtC in
                                    al_exploit_write_dir(pairC, srcC, tgtC, { _, msg in
                                        guard let msg = msg else { return }
                                        let line = String(cString: msg)
                                        DispatchQueue.main.async { AppViewModel.shared?.passthmFlashLog.append("    " + line) }
                                    }, nil, &outError)
                                }
                            }
                        }
                        if let p = outError {
                            lastErr = String(validatingUTF8: p)
                            al_string_free(p)
                        }
                        stepOk = (rc == 0)
                        cont.resume()
                    }
                }

                if !stepOk {
                    allOk = false
                    await MainActor.run {
                        self.passthmFlashLog.append("  ⚠️ 写入 \(targetName) 失败：\(lastErr ?? "未知错误")")
                    }
                } else {
                    await MainActor.run {
                        self.passthmFlashLog.append("  ✅ 已注入 \(targetName)")
                    }
                }

                await MainActor.run {
                    self.passthmFlashProgress = 0.2 + Double(idx + 1) * 0.25
                }
            }

            try? FileManager.default.removeItem(at: stageThemeDir)

            await MainActor.run {
                if allOk {
                    self.passthmFlashProgress = 1.0
                    self.passthmFlashPhase = .done(ok: true)
                    self.passthmFlashLog.append("🎉 密码盘主题已应用！锁屏后即可看到效果。")
                    self.successAlertMessage = "密码盘主题应用成功！\n\n请锁定 iPhone（或重启设备）后查看新的密码键盘。")
                    self.showSuccessAlert = true
                } else {
                    self.passthmFlashPhase = .done(ok: false)
                    self.passthmFlashLog.append("❌ 部分主题注入失败。")
                }
            }
        }
    }

    func exportPassthm() -> URL? {
        let keys = effectiveKeys
        guard !keys.isEmpty else {
            errorMessage = "导出前请至少设置一个按键。")
            return nil
        }
        do {
            let zipData = try PasscodeThemePackager.buildPassthm(
                keys: keys,
                telephonyVersion: targetTelephonyVersion,
                language: passcodeLanguageTarget,
                bold: passcodeBoldTarget
            )
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("AirCard_Custom_\(Int(Date().timeIntervalSince1970)).passthm")
            try zipData.write(to: tempURL)
            self.exportedThemeURL = tempURL
            self.showShareSheet = true
            return tempURL
        } catch {
            errorMessage = "导出主题失败：\(error.localizedDescription)"
            return nil
        }
    }

    func resetPosterPosition() {
        posterZoom = 1.0
        posterOffset = .zero
        updatePosterSlicing()
    }

    func adoptThemeIntoCreator() {
        guard let theme = loadedTheme else { return }
        for (digit, img) in theme.keysPreview {
            customKeys[digit] = img
            rawIndividualImages[digit] = img
            individualOffsets[digit] = .zero
            individualZooms[digit] = 1.0
        }
        selectedKeyDigit = nil
        sliceMode = .individualKeys
        passcodeMode = .themeCreator
    }

    func appendLog(_ line: String) {
        log.append(line)
    }

    // MARK: - Tendies / 壁纸

    func loadSavedTendies() {
        if let data = UserDefaults.standard.data(forKey: "aircard.saved_tendies"),
           let items = try? JSONDecoder().decode([TendieItem].self, from: data) {
            self.tendieItems = items.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
        }
    }

    func saveTendieItems() {
        if let data = try? JSONEncoder().encode(tendieItems) {
            UserDefaults.standard.set(data, forKey: "aircard.saved_tendies")
        }
    }

    func importTendieFiles(urls: [URL]) async {
        guard !urls.isEmpty else { return }
        var importedCount = 0
        var lastImportedName = ""
        for url in urls {
            do {
                let item = try await TendiesEngine.shared.importTendie(from: url)
                await MainActor.run {
                    self.tendieItems.removeAll(where: { $0.fileName == item.fileName })
                    self.tendieItems.append(item)
                    self.saveTendieItems()
                    importedCount += 1
                    lastImportedName = item.name
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "导入 \(url.lastPathComponent) 失败：\(error.localizedDescription)"
                }
            }
        }
    }

    func deleteTendie(item: TendieItem) {
        try? FileManager.default.removeItem(at: item.fileURL)
        tendieItems.removeAll(where: { $0.id == item.id })
        saveTendieItems()
    }

    func autoDetectPosterBoardContainer(silent: Bool = false) async {
        let pairingPath = PairingController.pairingFilePath()
        guard FileManager.default.fileExists(atPath: pairingPath) else {
            if !silent {
                await MainActor.run {
                    self.errorMessage = "当前没有生效的配对文件，请先在「配对」标签页完成配对。")
                }
            }
            return
        }

        await MainActor.run { self.isDetectingContainer = true }
        defer {
            Task { @MainActor in self.isDetectingContainer = false }
        }

        do {
            let container = try await TendiesEngine.shared.detectPosterBoardContainer(pairingPath: pairingPath)
            await MainActor.run {
                self.posterBoardContainer = container
                UserDefaults.standard.set(container, forKey: "aircard.posterboard_container")
            }
        } catch {
            if !silent {
                await MainActor.run {
                    self.errorMessage = "自动检测失败：\(error.localizedDescription)\n请确保 LocalDevVPN 已连接，且设备处于解锁状态。")
                }
            }
        }
    }

    func flashSelectedTendies() async {
        let selected = tendieItems.filter { $0.isSelected }
        guard !selected.isEmpty else {
            errorMessage = "没有选择要刷入的壁纸。")
            return
        }

        let pairingPath = PairingController.pairingFilePath()
        guard FileManager.default.fileExists(atPath: pairingPath) else {
            errorMessage = "当前没有生效的配对文件，请先完成设备配对。")
            return
        }

        var container = posterBoardContainer.trimmingCharacters(in: .whitespacesAndNewlines)
        if container.isEmpty {
            do {
                container = try await TendiesEngine.shared.detectPosterBoardContainer(pairingPath: pairingPath)
                self.posterBoardContainer = container
                UserDefaults.standard.set(container, forKey: "aircard.posterboard_container")
            } catch {
                errorMessage = "无法自动找到 PosterBoard 容器。请确保 LocalDevVPN 已连接且 iPhone 已解锁。")
                return
            }
        }

        tendiesFlashPhase = .running
        tendiesFlashProgress = 0
        tendiesFlashLog = []

        do {
            try await TendiesEngine.shared.flashTendies(
                items: selected,
                containerPath: container,
                resetProtections: resetPBProtections,
                pairingPath: pairingPath,
                log: { [weak self] line in
                    DispatchQueue.main.async {
                        self?.tendiesFlashLog.append(line)
                    }
                },
                progress: { [weak self] p in
                    DispatchQueue.main.async {
                        self?.tendiesFlashProgress = p
                    }
                }
            )
            tendiesFlashPhase = .done(ok: true)
            tendiesFlashProgress = 1.0
            tendiesFlashLog.append("🎉 壁纸应用成功！")
            tendiesFlashLog.append("⚡ 正在触发 NeoSpring 重启界面...")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.isNeoSpringing = true
                RespringHelper.triggerNeoSpring()
            }
        } catch {
            tendiesFlashLog.append("❌ 错误：\(error.localizedDescription)")
            tendiesFlashPhase = .done(ok: false)
        }
    }

    func respringDevice() {
        tendiesFlashLog.append("⚡ 正在触发 NeoSpring 重启界面...")
        isNeoSpringing = true
        RespringHelper.triggerNeoSpring()
    }

    func reset() {
        cardFlashPhase = .idle
        cardFlashProgress = 0
        passthmFlashPhase = .idle
        passthmFlashProgress = 0
        tendiesFlashPhase = .idle
        tendiesFlashProgress = 0
        errorMessage = nil
    }
}
