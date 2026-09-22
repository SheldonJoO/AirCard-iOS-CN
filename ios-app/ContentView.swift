import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

// MARK: - 通用工具方法

func logLineColor(_ line: String) -> Color {
    if line.contains("✅") || line.contains("🎉") { return .green }
    if line.contains("❌") { return .red }
    if line.contains("⚠️") { return .orange }
    return .secondary
}

// MARK: - 导出 .passthm 用的系统分享面板

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 致谢页面

struct CreditsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 顶部品牌区
                    VStack(spacing: 8) {
                        Image(systemName: "creditcard.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue)

                        Text("AirCard-iOS")
                            .font(.title2.bold())

                        Text("Apple 钱包卡面与密码盘主题 · 支持 iOS 18+")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 10)

                    Divider()

                    VStack(alignment: .leading, spacing: 14) {
                        // mak5er（主开发者）
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("主开发者", systemImage: "crown.fill")
                                    .font(.caption.bold().uppercaseSmallCaps())
                                    .foregroundStyle(.orange)
                                Spacer()
                                Text("负责人")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }

                            HStack(spacing: 8) {
                                Text("@mak5er")
                                    .font(.headline.bold())

                                Spacer()

                                Link(destination: URL(string: "https://github.com/mak5er")!) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "link")
                                        Text("GitHub")
                                    }
                                    .font(.caption.bold())
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Link(destination: URL(string: "https://x.com/mak5er")!) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "bubble.left.and.bubble.right.fill")
                                        Text("Twitter / X")
                                    }
                                    .font(.caption.bold())
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // merybist（基础 IPA 开发者）
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("基础 IPA 开发者", systemImage: "hammer.fill")
                                    .font(.caption.bold().uppercaseSmallCaps())
                                    .foregroundStyle(.blue)
                                Spacer()
                                Text("基础")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }

                            HStack(spacing: 8) {
                                Text("@merybist")
                                    .font(.headline.bold())

                                Spacer()

                                Link(destination: URL(string: "https://github.com/merybist")!) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "link")
                                        Text("GitHub")
                                    }
                                    .font(.caption.bold())
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Link(destination: URL(string: "https://x.com/merybist")!) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "bubble.left.and.bubble.right.fill")
                                        Text("Twitter / X")
                                    }
                                    .font(.caption.bold())
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // 技术致谢
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "bolt.shield.fill")
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("核心漏洞利用")
                                        .font(.subheadline.bold())
                                    Text("airlift（AirTraffic 同步沙盒逃逸）")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Divider()

                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.title3)
                                    .foregroundStyle(.purple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("密码盘主题")
                                        .font(.subheadline.bold())
                                    Text(".passthm 标准格式（Cowabunga / Nugget）")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Divider()

                            HStack(spacing: 12) {
                                Image(systemName: "bolt.fill")
                                    .font(.title3)
                                    .foregroundStyle(.yellow)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("NeoSpring 与 PosterBoard")
                                        .font(.subheadline.bold())
                                    Text("SpringBoard 重载与 .tendies 壁纸（@neonmodder123、@skadz108、@rooootdev）")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("致谢")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 可滚动的紧凑日志视图（一键复制）

struct CompactLogView: View {
    let title: String
    let lines: [String]
    var onClear: (() -> Void)? = nil
    @State private var copied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if let onClear = onClear, !lines.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .padding(.trailing, 6)
                }
                Button {
                    UIPasteboard.general.string = lines.joined(separator: "\n")
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        copied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        var t2 = Transaction()
                        t2.disablesAnimations = true
                        withTransaction(t2) {
                            copied = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .bold))
                        Text(copied ? "已复制" : "复制")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(copied ? .green : .blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
                .transaction { $0.animation = nil }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(logLineColor(line))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 180)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 0.5)
                )
                .onChange(of: lines.count) { _, _ in
                    if !lines.isEmpty {
                        proxy.scrollTo(lines.count - 1, anchor: .bottom)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 系统文件选择器

struct DocumentPickerView: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let onPick: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let shouldStop = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStop { url.stopAccessingSecurityScopedResource() }
            }
            parent.onPick(url)
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

// MARK: - 根标签页

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        TabView(selection: $vm.selectedTab) {
            PairingTab()
                .tabItem { Label("配对", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(AppTab.pairing)

            WalletCardsTab()
                .tabItem { Label("钱包卡片", systemImage: "creditcard.fill") }
                .tag(AppTab.walletCards)

            PasscodeThemeTab()
                .tabItem { Label("密码盘", systemImage: "lock.circle.fill") }
                .tag(AppTab.passcodeThemes)

            TendiesView()
                .tabItem { Label("壁纸", systemImage: "photo.stack.fill") }
                .tag(AppTab.wallpapers)
        }
        .alert("提示", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("好") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("成功！🎉", isPresented: $vm.showSuccessAlert) {
            Button("好") {}
        } message: {
            Text(vm.successAlertMessage)
        }
        .sheet(isPresented: $vm.showShareSheet) {
            if let url = vm.exportedThemeURL {
                ShareSheet(items: [url])
            }
        }
        .onAppear {
            vm.showSuccessAlert = false
            vm.successAlertMessage = ""
        }
    }
}

// MARK: - 配对标签页

struct PairingTab: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showDeleteConfirm = false
    @State private var showCredits = false

    var body: some View {
        NavigationStack {
            Form {
                // 头部信息
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "creditcard.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            Text("AirCard-iOS")
                                .font(.title2.bold())
                            Spacer()
                            Text("iOS \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion) · v1.3")
                                .font(.caption.monospaced().bold())
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        Text("借助 AirTraffic 沙盒逃逸，直接在设备本地应用自定义钱包卡面与密码盘主题。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // 网络 / VPN 状态
                Section("网络") {
                    VPNStatusRow(vm: vm)
                }

                // 配对状态
                Section("当前配对") {
                    HStack(spacing: 10) {
                        if vm.hasPairingFile {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("已就绪，可以执行 ✅")
                                    .font(.subheadline.bold())
                                Text("\(vm.pairingFileName) (\(vm.pairingFileSizeString))")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("尚未配对")
                                    .font(.subheadline.bold())
                                Text("点击下方「配对本机」进行配对。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if vm.hasPairingFile {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .confirmationDialog(
                    "删除配对会话？",
                    isPresented: $showDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button("删除", role: .destructive) { vm.deletePairingFile() }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("当前的配对凭证将被移除。")
                }

                // 本机配对区域（所有 iOS 版本均可用）
                Section("在本机配对") {
                    if vm.pairingPhase == .pairing {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.85)
                                Text(vm.pairingStatus.isEmpty ? "正在启动本机配对服务…" : vm.pairingStatus)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let pin = vm.pairingPIN {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("请在本机输入以下配对码：")
                                        .font(.caption2.bold().uppercaseSmallCaps())
                                        .foregroundStyle(.secondary)

                                    HStack(alignment: .center, spacing: 0) {
                                        Text(pin)
                                            .font(.system(size: 40, weight: .black, design: .monospaced))
                                            .foregroundStyle(.orange)
                                        Spacer()
                                        Button {
                                            UIPasteboard.general.string = pin
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        } label: {
                                            Label("复制", systemImage: "doc.on.doc")
                                                .font(.caption.bold())
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.orange)
                                    }

                                    Text("设置 › 隐私与安全性 › 开发者模式 › 与 AirCard-iOS 配对")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.primary)

                                     Button {
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    } label: {
                                        Label("立即打开「设置」", systemImage: "arrow.up.forward.app")
                                            .bold()
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                                }
                                .padding(14)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button(role: .cancel) {
                                vm.cancelPairing()
                            } label: {
                                HStack(spacing: 8) {
                                    Spacer()
                                    Image(systemName: "xmark")
                                    Text("取消配对")
                                    Spacer()
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    } else {
                        VStack(spacing: 12) {
                            if !vm.pairingStatus.isEmpty && vm.pairingStatus != "idle" {
                                Text(vm.pairingStatus)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(
                                        vm.pairingStatus.contains("✅") ? .green :
                                        vm.pairingStatus.contains("❌") || vm.pairingStatus.contains("失败") ? .red :
                                        .secondary
                                    )
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            Button {
                                vm.startPairing()
                            } label: {
                                HStack(spacing: 8) {
                                    Spacer()
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.body.weight(.semibold))
                                    Text(vm.hasPairingFile ? "重新配对本机" : "配对本机")
                                        .font(.headline)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                    }
                }

                if !vm.log.isEmpty {
                    Section {
                        CompactLogView(
                            title: "活动日志（\(vm.log.count) 行）",
                            lines: vm.log,
                            onClear: { vm.log.removeAll() }
                        )
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 60)
            }
            .navigationTitle("AirCard-iOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCredits = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                            Text("致谢")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.pink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.pink.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            .sheet(isPresented: $showCredits) {
                CreditsSheet()
            }
            .onAppear {
                vm.refreshNetworkStatus()
                vm.refreshPairingFile()
            }
            .refreshable {
                vm.refreshNetworkStatus()
                vm.refreshPairingFile()
            }
        }
    }
}

// MARK: - VPN 状态行

struct VPNStatusRow: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: vm.vpnUp
                      ? "checkmark.shield.fill"
                      : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(vm.vpnUp ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.vpnUp ? "回环 VPN 已连接" : "未检测到回环 VPN")
                        .font(.subheadline.bold())
                    Text(vm.vpnUp
                         ? "RSD 隧道已就绪，可以执行注入。"
                         : "请先连接 LocalDevVPN，再执行刷入。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !vm.vpnUp {
                VStack(alignment: .leading, spacing: 6) {
                    Text("配置 LocalDevVPN：")
                        .font(.caption.bold())
                    ForEach([
                        "1. 打开 LocalDevVPN App 并点击连接。",
                        "2. 返回 AirCard-iOS，状态指示灯会变绿。"
                    ], id: \.self) { step in
                        Text(step)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Link("打开 LocalDevVPN",
                         destination: URL(string: "localdevvpn://")!)
                        .font(.caption.bold())
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 8) {
                Text("设备 IP：")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("10.7.0.1", text: $vm.deviceIP)
                    .font(.caption.monospaced())
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(width: 120)
                Spacer()
                Button {
                    vm.refreshNetworkStatus()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            if !vm.networkDetail.isEmpty {
                Text(vm.networkDetail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Apple 钱包卡片视图组件（AirCard 原版风格）

struct WalletCardView: View {
    let card: CardItem
    let cardIndex: Int
    let onToggleSelected: (Bool) -> Void
    let onPickImage: () -> Void
    let onClearImage: () -> Void
    let onDelete: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            // 拟真的 Apple 钱包卡片样式（1.586 : 1 宽高比）
            GeometryReader { geo in
                let width = geo.size.width
                let height = width / 1.586

                ZStack {
                    if let img = card.uiImage {
                        // 已应用自定义卡面
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: width, height: height)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            // Apple 钱包卡片的高光叠加层
                            LinearGradient(
                                colors: [.white.opacity(0.18), .clear, .black.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            // 右上角的移除按钮
                            Button(action: onClearImage) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .background(Circle().fill(Color.black.opacity(0.55)))
                            }
                            .buttonStyle(.plain)
                            .padding(10)
                        }
                    } else {
                        // 空卡片占位样式
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(uiColor: .secondarySystemBackground),
                                            Color(uiColor: .tertiarySystemBackground)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    Color.secondary.opacity(0.25),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                                )

                            // 非接触支付与芯片图标
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "wave.3.right")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary.opacity(0.6))
                                    Spacer()
                                    Image(systemName: "creditcard")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.secondary.opacity(0.5))
                                }
                                .padding(14)
                                Spacer()
                            }

                            // 中央操作提示
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.blue)

                                Text("指定卡面")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)

                                Text("点击选择图片")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .contentShape(Rectangle())
                .onTapGesture { onPickImage() }
            }
            .aspectRatio(1.586, contentMode: .fit)

            // 卡片控件与信息栏
            HStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { card.isSelected },
                    set: { onToggleSelected($0) }
                ))
                .labelsHidden()

                Text("卡片 #\(cardIndex + 1)")
                    .font(.system(size: 13, weight: .semibold))

                // 等宽字体哈希药丸（带复制按钮）
                HStack(spacing: 4) {
                    Text(card.id.prefix(8) + "…" + card.id.suffix(6))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Button {
                        UIPasteboard.general.string = card.id
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(copied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(uiColor: .systemFill))
                .clipShape(Capsule())

                Spacer()

                if card.uiImage != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 14))
                }

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(card.isSelected ? Color.blue.opacity(0.35) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - 钱包卡片标签页

struct WalletCardsTab: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var newHashText = ""
    @State private var showAddSheet = false
    enum ActiveCardPicker: Identifiable {
        case singleCard(String)
        case bulkAll
        var id: String {
            switch self {
            case .singleCard(let id): return id
            case .bulkAll: return "bulk_all"
            }
        }
    }
    @State private var activePicker: ActiveCardPicker? = nil
    @State private var showSourceDialog: Bool = false
    @State private var isPhotosPickerPresented: Bool = false
    @State private var isDocumentPickerPresented: Bool = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showCredits = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    scannerBanner

                    if vm.cards.isEmpty {
                        walletEmptyState
                            .padding(.top, 40)
                    } else {
                        cardsList
                    }
                }
                .padding(.vertical)
                .transaction { $0.animation = nil }
            }
            .transaction { $0.animation = nil }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 60)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("钱包卡片（\(vm.cards.count)）")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        vm.toggleCardScanning()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: vm.isScanningCards ? "stop.circle.fill" : "wave.3.left.circle")
                            Text(vm.isScanningCards ? "停止扫描" : "扫描卡片")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(vm.isScanningCards ? .red : .blue)
                    }
                    .transaction { $0.animation = nil }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showAddSheet = true
                        } label: {
                            Label("手动添加卡片", systemImage: "plus")
                        }
                        if !vm.cards.isEmpty {
                            Button {
                                activePicker = .bulkAll
                                showSourceDialog = true
                            } label: {
                                Label("为所有卡片设置卡面…", systemImage: "photo.on.rectangle.angled")
                            }

                            Divider()

                            Button {
                                vm.selectAllCards(true)
                            } label: {
                                Label("全选", systemImage: "checkmark.circle")
                            }

                            Button {
                                vm.selectAllCards(false)
                            } label: {
                                Label("取消全选", systemImage: "circle")
                            }

                            Divider()

                            Button(role: .destructive) {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                    vm.clearAllCards()
                                }
                            } label: {
                                Label("清空所有卡片", systemImage: "trash")
                            }

                            Divider()

                            Button {
                                showCredits = true
                            } label: {
                                Label("致谢", systemImage: "heart.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    flashButton
                }
            }
            .sheet(isPresented: $showCredits) {
                CreditsSheet()
            }
            .sheet(isPresented: $showAddSheet) {
                AddCardSheet(hashText: $newHashText) {
                    vm.addCardHash(newHashText)
                    newHashText = ""
                    showAddSheet = false
                }
            }
            .confirmationDialog("选择图片来源", isPresented: $showSourceDialog, titleVisibility: .visible) {
                Button {
                    isPhotosPickerPresented = true
                } label: {
                    Label("照片图库", systemImage: "photo.on.rectangle")
                }
                Button {
                    isDocumentPickerPresented = true
                } label: {
                    Label("从「文件」中选择…", systemImage: "folder")
                }
                Button("取消", role: .cancel) {
                    activePicker = nil
                }
            }
            .photosPicker(
                isPresented: $isPhotosPickerPresented,
                selection: $selectedPhotos,
                maxSelectionCount: 1,
                matching: .images
            )
            .onChange(of: selectedPhotos) { _, items in
                guard let item = items.first, let picker = activePicker else {
                    if items.isEmpty { activePicker = nil }
                    return
                }
                let currentPicker = picker
                Task {
                    if let image = await item.loadUIImage(maxDimension: 2560) {
                        await MainActor.run {
                            switch currentPicker {
                            case .singleCard(let cardId):
                                vm.setCardImage(for: cardId, image: image)
                            case .bulkAll:
                                vm.setSkinForAllCards(image: image)
                            }
                        }
                    }
                    await MainActor.run {
                        selectedPhotos = []
                        activePicker = nil
                    }
                }
            }
            .sheet(isPresented: $isDocumentPickerPresented) {
                DocumentPickerView(allowedContentTypes: [
                    .image, .png, .jpeg, .heic,
                    UTType(filenameExtension: "webp") ?? .image,
                    UTType(filenameExtension: "tiff") ?? .image
                ]) { url in
                    guard let picker = activePicker else { return }
                    if let data = try? Data(contentsOf: url),
                       let image = ImageEngine.safeImageFromData(data, maxDimension: 2560) {
                        switch picker {
                        case .singleCard(let cardId):
                            vm.setCardImage(for: cardId, image: image)
                        case .bulkAll:
                            vm.setSkinForAllCards(image: image)
                        }
                    }
                    activePicker = nil
                }
            }
        }
    }

    @ViewBuilder
    private var scannerBanner: some View {
        if vm.isScanningCards || !vm.scanStatusText.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if vm.isScanningCards {
                        ProgressView().scaleEffect(0.85)
                        Text("实时扫描已开启")
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)
                    } else {
                        Image(systemName: "wave.3.left.circle")
                            .foregroundStyle(.secondary)
                        Text("扫描器状态")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if vm.isScanningCards {
                        Button("停止") {
                            vm.stopCardScanning()
                        }
                        .font(.caption.bold())
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                    }
                }
                Text(vm.scanStatusText)
                    .font(.caption)
                    .foregroundStyle(vm.scanStatusText.contains("已停止") || vm.scanStatusText.contains("错误") ? .orange : .secondary)
            }
            .padding(14)
            .background(vm.isScanningCards ? Color.blue.opacity(0.12) : Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .transaction { $0.animation = nil }
        }
    }

    @ViewBuilder
    private var cardsList: some View {
        VStack(spacing: 16) {
            ForEach(vm.cards, id: \.id) { card in
                let cardIndex = vm.cards.firstIndex(where: { $0.id == card.id }) ?? 0
                WalletCardView(
                    card: card,
                    cardIndex: cardIndex,
                    onToggleSelected: { isSelected in
                        vm.setCardSelected(id: card.id, selected: isSelected)
                    },
                    onPickImage: {
                        activePicker = .singleCard(card.id)
                        showSourceDialog = true
                    },
                    onClearImage: { vm.clearCardImage(for: card.id) },
                    onDelete: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        vm.deleteCard(id: card.id)
                    }
                )
                .id(card.id)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.85).combined(with: .opacity)
                ))
            }

            if !vm.cardFlashLog.isEmpty {
                CompactLogView(
                    title: "刷入日志（\(vm.cardFlashLog.count) 行）",
                    lines: vm.cardFlashLog,
                    onClear: { vm.cardFlashLog.removeAll() }
                )
                .padding(.top, 8)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var flashButton: some View {
        Button {
            vm.flashCards()
        } label: {
            HStack(spacing: 6) {
                if case .running = vm.cardFlashPhase {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.75)
                    Text("刷入中…")
                        .font(.system(size: 13, weight: .semibold))
                } else if case .done(let ok) = vm.cardFlashPhase, !ok {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text("重试")
                        .font(.system(size: 13, weight: .semibold))
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("刷入")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .padding(.horizontal, 4)
            .frame(minHeight: 28)
        }
        .buttonStyle(.borderedProminent)
        .tint({
            if case .done(let ok) = vm.cardFlashPhase, !ok {
                return Color.orange
            }
            return Color.blue
        }())
        .disabled(!vm.canFlashCards || vm.cardFlashPhase == .running)
        .animation(.easeInOut(duration: 0.2), value: vm.cardFlashPhase)
    }

    private var walletEmptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "creditcard.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.blue.opacity(0.8))

            Text("尚未检测到卡片")
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Text("1.")
                        .bold()
                        .foregroundStyle(.blue)
                    Text("点击上方工具栏中的**「扫描卡片」**。")
                }
                HStack(alignment: .top, spacing: 10) {
                    Text("2.")
                        .bold()
                        .foregroundStyle(.blue)
                    Text("在本机**双击侧边按钮**（Apple Pay），通过 **Face ID** 验证后**轻点你的卡片**。")
                }
                HStack(alignment: .top, spacing: 10) {
                    Text("3.")
                        .bold()
                        .foregroundStyle(.blue)
                    Text("卡片会自动出现在这里！")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Button {
                    vm.toggleCardScanning()
                } label: {
                    HStack(spacing: 6) {
                        Spacer()
                        Image(systemName: vm.isScanningCards ? "stop.circle.fill" : "wave.3.left.circle")
                        Text(vm.isScanningCards ? "停止扫描" : "扫描卡片")
                        Spacer()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.isScanningCards ? .red : .blue)
                .transaction { $0.animation = nil }

                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "plus")
                        Text("手动添加")
                        Spacer()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.bordered)
                .transaction { $0.animation = nil }
            }
            .padding(.horizontal, 24)
            .transaction { $0.animation = nil }
        }
        .frame(maxWidth: .infinity)
        .transaction { $0.animation = nil }
    }
}

// MARK: - 添加卡片弹层

struct AddCardSheet: View {
    @Binding var hashText: String
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("卡片哈希") {
                    TextField("粘贴卡片哈希（例如 M6nDwZrkYbFl…）", text: $hashText, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .lineLimit(4...8)
                }
                Section {
                    Text("你可以一次添加多个哈希，用空格、逗号或换行分隔。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("添加卡片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") { onAdd() }
                        .disabled(hashText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .bold()
                }
            }
        }
    }
}

// MARK: - 密码盘主题标签页

struct PasscodeThemeTab: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showCredits = false

    var body: some View {
        NavigationStack {
            Form {
                // 模式选择器
                Section {
                    Picker("模式", selection: $vm.passcodeMode) {
                        ForEach(CreatorMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if vm.passcodeMode == .applyTheme {
                    ApplyThemeSection()
                } else {
                    ThemeCreatorSection()
                }

                // 刷入日志
                if !vm.passthmFlashLog.isEmpty {
                    Section {
                        CompactLogView(
                            title: "刷入日志（\(vm.passthmFlashLog.count) 行）",
                            lines: vm.passthmFlashLog,
                            onClear: { vm.passthmFlashLog.removeAll() }
                        )
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 60)
            }
            .navigationTitle("密码盘主题")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCredits = true
                    } label: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                    }
                }
            }
            .sheet(isPresented: $showCredits) {
                CreditsSheet()
            }
            .onAppear { vm.scanDocumentsDirectory() }
        }
    }
}

// MARK: 应用主题区域

struct ApplyThemeSection: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showDocumentPicker = false

    var body: some View {
        // 直接放到 Documents 文件夹中的主题
        if !vm.documentsThemes.isEmpty {
            Section("App 文件夹内的主题（我的 iPhone › AirCard-iOS）") {
                ForEach(vm.documentsThemes, id: \.self) { file in
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(.pink)
                        Text(file)
                            .font(.system(size: 13, design: .monospaced))
                        Spacer()
                        Button("载入") {
                            vm.loadPassthmFromDocuments(filename: file)
                        }
                        .font(.caption.bold())
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }

        Section("浏览文件") {
            HStack {
                Button {
                    showDocumentPicker = true
                } label: {
                    Label(vm.loadedTheme == nil ? "从「文件」中选择 .passthm…" : "更换 .passthm…",
                          systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if vm.loadedTheme != nil {
                    Button {
                        vm.clearLoadedTheme()
                    } label: {
                        Text("清除")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView(allowedContentTypes: [
                    UTType(filenameExtension: "passthm") ?? .archive,
                    UTType.zip,
                    UTType.archive
                ]) { url in
                    vm.loadPassthm(url: url)
                }
            }
        }

        if let theme = vm.loadedTheme {
            Section("锁屏交互预览") {
                KeypadPreviewView(keys: theme.keysPreview)
                    .listRowInsets(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
                    .listRowBackground(Color.clear)
            }

            Section("主题信息") {
                LabeledContent("主题内文件数", value: "\(theme.fileCount)")
                LabeledContent("已定制的数字", value: "\(theme.keysPreview.count) 个按键")

                Button {
                    vm.adoptThemeIntoCreator()
                } label: {
                    Label("在主题制作器中编辑", systemImage: "pencil")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
            }

            PasscodeTargetSection()

            Section {
                VStack(spacing: 12) {
                    flashButton

                    Button(role: .destructive) {
                        vm.clearLoadedTheme()
                    } label: {
                        HStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "trash")
                            Text("移除 / 卸载主题")
                            Spacer()
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            }
        }
    }

    @ViewBuilder
    private var flashButton: some View {
        if case .running = vm.passthmFlashPhase {
            HStack(spacing: 10) {
                ProgressView()
                VStack(alignment: .leading, spacing: 4) {
                    Text("正在刷入主题…").font(.subheadline.bold())
                    ProgressView(value: vm.passthmFlashProgress)
                }
            }
            .padding(.vertical, 4)
        } else if case .done(let ok) = vm.passthmFlashPhase, !ok {
            Button {
                vm.flashPassthm()
            } label: {
                HStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                    Text("重试刷入主题")
                    Spacer()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(!vm.canFlashPassthm)
        } else {
            Button {
                vm.flashPassthm()
            } label: {
                HStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "bolt.fill")
                    Text("刷入主题到本机")
                    Spacer()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.canFlashPassthm)
        }
    }
}

// MARK: - 刷入目标区域（与 AirCard macOS 版一致）

struct PasscodeTargetSection: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.badge.clock")
                        .foregroundColor(.blue)
                        .font(.headline)
                    Text("刷入目标与语言")
                        .font(.headline)
                }

                // 1. 目标系统
                VStack(alignment: .leading, spacing: 4) {
                    Text("系统缓存")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Picker("系统缓存", selection: $vm.targetTelephonyVersion) {
                        Text("TelephonyUI-10（iOS 18+）").tag("TelephonyUI-10")
                        Text("TelephonyUI-9（iOS 16–17）").tag("TelephonyUI-9")
                        Text("TelephonyUI-8（iOS 14–15）").tag("TelephonyUI-8")
                        Text("通用（全部）").tag("all")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                Divider()

                // 2. 系统语言
                VStack(alignment: .leading, spacing: 4) {
                    Text("系统语言")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Picker("系统语言", selection: $vm.passcodeLanguageTarget) {
                        ForEach(PasscodeLanguageTarget.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                Divider()

                // 3. 字重 / 样式
                VStack(alignment: .leading, spacing: 4) {
                    Text("字重 / 样式")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Picker("字重 / 样式", selection: $vm.passcodeBoldTarget) {
                        ForEach(PasscodeBoldTarget.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // 动态提示
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: vm.passcodeLanguageTarget == .all && vm.passcodeBoldTarget == .both ? "globe" : "bolt.fill")
                        .font(.caption)
                        .foregroundColor(vm.passcodeLanguageTarget == .all && vm.passcodeBoldTarget == .both ? .secondary : .orange)
                        .padding(.top, 1)

                    if vm.passcodeLanguageTarget == .all && vm.passcodeBoldTarget == .both {
                        Text("通用模式会为所有语言和粗体文本刷入约 600 个文件。指定某一语言（例如乌克兰语）可大幅加快刷入速度。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("已选择快速模式：仅针对 \(vm.passcodeLanguageTarget.rawValue) 与 \(vm.passcodeBoldTarget.rawValue)。")
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: 主题制作器区域

struct ThemeCreatorSection: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var selectedDigitForPicker: String? = nil
    @State private var showKeySourceDialog: Bool = false
    @State private var isKeyPhotosPickerPresented: Bool = false
    @State private var isKeyDocumentPickerPresented: Bool = false
    @State private var selectedKey: [PhotosPickerItem] = []

    @State private var showPosterSourceDialog: Bool = false
    @State private var isPosterPhotosPickerPresented: Bool = false
    @State private var isPosterDocumentPickerPresented: Bool = false
    @State private var selectedPoster: [PhotosPickerItem] = []

    var body: some View {
        Section("切图模式") {
            Picker("", selection: $vm.sliceMode) {
                ForEach(SliceMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
        }

        if vm.sliceMode == .posterSlice {
            posterSliceSection
        } else {
            individualKeysSection
        }

        // 预览
        Section("锁屏交互预览") {
            KeypadPreviewView(keys: vm.effectiveKeys)
                .listRowInsets(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
                .listRowBackground(Color.clear)
        }

        PasscodeTargetSection()

        // 操作区域
        Section {
            VStack(spacing: 12) {
                flashButton

                if !vm.effectiveKeys.isEmpty {
                    Button {
                        _ = vm.exportPassthm()
                    } label: {
                        HStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                            Text("导出 .passthm…")
                            Spacer()
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        vm.clearAllCreator()
                    } label: {
                        HStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "trash")
                            Text("清空全部")
                            Spacer()
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        }
    }

    private var posterSliceSection: some View {
        Group {
            Section("海报图") {
                Button {
                    showPosterSourceDialog = true
                } label: {
                    Label(vm.posterImage == nil ? "选择键盘海报图…" : "更换图片…",
                          systemImage: "photo")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .confirmationDialog("选择海报图来源", isPresented: $showPosterSourceDialog, titleVisibility: .visible) {
                Button {
                    isPosterPhotosPickerPresented = true
                } label: {
                    Label("照片图库", systemImage: "photo.on.rectangle")
                }
                Button {
                    isPosterDocumentPickerPresented = true
                } label: {
                    Label("从「文件」中选择…", systemImage: "folder")
                }
                Button("取消", role: .cancel) {}
            }
            .photosPicker(
                isPresented: $isPosterPhotosPickerPresented,
                selection: $selectedPoster,
                maxSelectionCount: 1,
                matching: .images
            )
            .onChange(of: selectedPoster) { _, items in
                guard let item = items.first else { return }
                Task {
                    if let image = await item.loadUIImage(maxDimension: 2560) {
                        await MainActor.run { vm.setPosterImage(image) }
                    }
                    await MainActor.run { selectedPoster = [] }
                }
            }
            .sheet(isPresented: $isPosterDocumentPickerPresented) {
                DocumentPickerView(allowedContentTypes: [
                    .image, .png, .jpeg, .heic,
                    UTType(filenameExtension: "webp") ?? .image,
                    UTType(filenameExtension: "tiff") ?? .image
                ]) { url in
                    if let data = try? Data(contentsOf: url),
                       let image = ImageEngine.safeImageFromData(data, maxDimension: 2560) {
                        vm.setPosterImage(image)
                    }
                }
            }

            if vm.posterImage != nil {
                Section("切图样式") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("", selection: $vm.maskToCircles) {
                            Text("无缝海报").tag(false)
                            Text("圆形按键").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: vm.maskToCircles) { _, _ in
                            vm.updatePosterSlicing()
                        }

                        Text(vm.maskToCircles ? "画面会被裁切成单个圆形按键图标。" : "画面无缝铺满整个拨号键盘，不做圆形裁切（Adobe Dog 风格）。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("缩放与构图")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("重置位置") {
                                withAnimation(.spring()) {
                                    vm.resetPosterPosition()
                                }
                            }
                            .font(.caption2)
                            .buttonStyle(.borderless)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "minus.magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.caption)

                            Slider(value: $vm.posterZoom, in: 0.5...3.0, step: 0.05)
                                .onChange(of: vm.posterZoom) { _, _ in
                                    vm.updatePosterSlicing()
                                }

                            Image(systemName: "plus.magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.caption)

                            Text(String(format: "%.1fx", vm.posterZoom))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .frame(width: 38, alignment: .trailing)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "hand.draw")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                            Text("在拨号盘预览上任意拖动即可调整位置")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var individualKeysSection: some View {
        Section("单个按键") {
            Text("点击某一行即可为该按键指定自定义图片。")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(KeypadLayout.allButtons) { btn in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .frame(width: 44, height: 44)
                        if let img = vm.customKeys[btn.digit] {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else {
                            Text(btn.digit)
                                .font(.title3.bold())
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("按键 \(btn.digit)")
                            .font(.subheadline.weight(.medium))
                        if !btn.letters.isEmpty {
                            Text(btn.letters)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if vm.customKeys[btn.digit] != nil {
                        Button(role: .destructive) {
                            vm.clearIndividualKey(digit: btn.digit)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDigitForPicker = btn.digit
                    showKeySourceDialog = true
                }
            }
        }
        .confirmationDialog("选择按键 \(selectedDigitForPicker ?? "") 的图片来源", isPresented: $showKeySourceDialog, titleVisibility: .visible) {
            Button {
                isKeyPhotosPickerPresented = true
            } label: {
                Label("照片图库", systemImage: "photo.on.rectangle")
            }
            Button {
                isKeyDocumentPickerPresented = true
            } label: {
                Label("从「文件」中选择…", systemImage: "folder")
            }
            Button("取消", role: .cancel) {
                selectedDigitForPicker = nil
            }
        }
        .photosPicker(
            isPresented: $isKeyPhotosPickerPresented,
            selection: $selectedKey,
            maxSelectionCount: 1,
            matching: .images
        )
        .onChange(of: selectedKey) { _, items in
            guard let item = items.first,
                  let digit = selectedDigitForPicker else {
                if items.isEmpty { selectedDigitForPicker = nil }
                return
            }
            let currentDigit = digit
            Task {
                if let image = await item.loadUIImage(maxDimension: 1024) {
                    await MainActor.run { vm.setIndividualKey(digit: currentDigit, image: image) }
                }
                await MainActor.run {
                    selectedKey = []
                    selectedDigitForPicker = nil
                }
            }
        }
        .sheet(isPresented: $isKeyDocumentPickerPresented) {
            DocumentPickerView(allowedContentTypes: [
                .image, .png, .jpeg, .heic,
                UTType(filenameExtension: "webp") ?? .image,
                UTType(filenameExtension: "tiff") ?? .image
            ]) { url in
                guard let digit = selectedDigitForPicker else { return }
                if let data = try? Data(contentsOf: url),
                   let image = ImageEngine.safeImageFromData(data, maxDimension: 1024) {
                    vm.setIndividualKey(digit: digit, image: image)
                }
                selectedDigitForPicker = nil
            }
        }
    }

    @ViewBuilder
    private var flashButton: some View {
        if case .running = vm.passthmFlashPhase {
            HStack(spacing: 10) {
                ProgressView()
                VStack(alignment: .leading, spacing: 4) {
                    Text("正在刷入主题…").font(.subheadline.bold())
                    ProgressView(value: vm.passthmFlashProgress)
                }
            }
            .padding(.vertical, 4)
        } else if case .done(let ok) = vm.passthmFlashPhase, !ok {
            Button {
                vm.flashPassthm()
            } label: {
                HStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                    Text("重试刷入主题")
                    Spacer()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(!vm.canFlashPassthm)
        } else {
            Button {
                vm.flashPassthm()
            } label: {
                HStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "bolt.fill")
                    Text("刷入主题到本机")
                    Spacer()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.canFlashPassthm)
        }
    }
}

// MARK: - 键盘预览（简洁现代的锁屏拨号盘预览）

struct KeypadPreviewView: View {
    @EnvironmentObject var vm: AppViewModel
    let keys: [String: UIImage]

    @State private var dragOffsetStart: CGPoint = .zero
    @State private var isDragging: Bool = false

    private func scaledPosterDimensions(for poster: UIImage, gridW: CGFloat, gridH: CGFloat) -> (width: CGFloat, height: CGFloat) {
        let imgW = poster.size.width
        let imgH = poster.size.height
        guard imgW > 0, imgH > 0 else { return (gridW, gridH) }

        let imgAspect = imgW / imgH
        let gridAspect = gridW / gridH

        if imgAspect > gridAspect {
            let h = gridH * vm.posterZoom
            return (width: h * imgAspect, height: h)
        } else {
            let w = gridW * vm.posterZoom
            return (width: w, height: w / imgAspect)
        }
    }

    var body: some View {
        let scale: CGFloat = 0.68
        let btnD: CGFloat = KeypadLayout.buttonDiameter * scale
        let colW: CGFloat = KeypadLayout.colWidth * scale
        let rowH: CGFloat = KeypadLayout.rowHeight * scale
        let gridW: CGFloat = KeypadLayout.gridWidth * scale
        let gridH: CGFloat = KeypadLayout.gridHeight * scale

        let isSeamlessPoster = (vm.passcodeMode == .themeCreator && vm.sliceMode == .posterSlice && !vm.maskToCircles && vm.posterImage != nil)

        ZStack {
            // 深色磨砂卡片背景
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.07, green: 0.07, blue: 0.09))

            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.clear, Color.black.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(spacing: 12) {
                // 拨号键盘网格
                ZStack {
                    // 图层 1：无缝海报模式下的背景画面
                    if isSeamlessPoster, let poster = vm.posterImage {
                        let dims = scaledPosterDimensions(for: poster, gridW: gridW, gridH: gridH)
                        Image(uiImage: poster)
                            .resizable()
                            .frame(width: dims.width, height: dims.height)
                            .position(
                                x: gridW / 2.0 + (vm.posterOffset.x * scale),
                                y: gridH / 2.0 + (vm.posterOffset.y * scale)
                            )
                    }

                    // 图层 2：10 个拨号按键
                    ForEach(KeypadLayout.allButtons) { btn in
                        let cx = CGFloat(btn.col) * colW + colW / 2
                        let cy = CGFloat(btn.row) * rowH + rowH / 2

                        keypadButton(btn: btn, btnD: btnD, scale: scale, isSeamlessPoster: isSeamlessPoster)
                            .position(x: cx, y: cy)
                    }
                }
                .frame(width: gridW, height: gridH)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if vm.passcodeMode == .themeCreator && vm.sliceMode == .posterSlice && vm.posterImage != nil {
                                if !isDragging {
                                    isDragging = true
                                    dragOffsetStart = vm.posterOffset
                                }
                                vm.posterOffset = CGPoint(
                                    x: dragOffsetStart.x + value.translation.width / scale,
                                    y: dragOffsetStart.y + value.translation.height / scale
                                )
                                vm.updatePosterSlicing()
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                            dragOffsetStart = vm.posterOffset
                        }
                )

                // 拖动提示条（仅在可拖动海报时显示）
                if vm.passcodeMode == .themeCreator && vm.sliceMode == .posterSlice && vm.posterImage != nil {
                    HStack(spacing: 5) {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 10))
                        Text("拖动预览可调整位置")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: (vm.passcodeMode == .themeCreator && vm.sliceMode == .posterSlice && vm.posterImage != nil) ? 320 : 295)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func keypadButton(btn: KeypadButtonGeometry, btnD: CGFloat, scale: CGFloat, isSeamlessPoster: Bool) -> some View {
        ZStack {
            if isSeamlessPoster {
                // 无缝模式：磨砂玻璃触控圆环
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: btnD, height: btnD)

                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.0)
                    .frame(width: btnD, height: btnD)

                VStack(spacing: 0) {
                    Text(btn.digit)
                        .font(.system(size: 26 * scale, weight: .light))
                        .foregroundStyle(.white.opacity(0.95))
                    if !btn.letters.isEmpty {
                        Text(btn.letters)
                            .font(.system(size: 8.5 * scale, weight: .semibold))
                            .tracking(0.8 * scale)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            } else if let img = keys[btn.digit] {
                // 自定义主题按键：纯画面，不叠加文字
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: btnD, height: btnD)

                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: btnD, height: btnD)
                    .clipShape(Circle())

                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                    .frame(width: btnD, height: btnD)
            } else {
                // 未定制按键的默认 iOS 拨号盘样式
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: btnD, height: btnD)

                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                    .frame(width: btnD, height: btnD)

                VStack(spacing: 0) {
                    Text(btn.digit)
                        .font(.system(size: 26 * scale, weight: .light))
                        .foregroundStyle(.white)
                    if !btn.letters.isEmpty {
                        Text(btn.letters)
                            .font(.system(size: 8.5 * scale, weight: .semibold))
                            .tracking(0.8 * scale)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
        }
        .frame(width: btnD, height: btnD)
    }
}
