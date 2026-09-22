//
//  TendiesEngine.swift
//  AirCard-iOS
//
//  用于解析、提取和刷入 PosterBoard .tendies 壁纸的引擎。
//

import UIKit
import Foundation
import AirliftFFI

public final class TendiesEngine {
    public static let shared = TendiesEngine()

    public static var tendiesStorageDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Tendies", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - 导入与解析

    public func importTendie(from sourceURL: URL) async throws -> TendieItem {
        let isSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileName = sourceURL.lastPathComponent
        let baseName = (fileName as NSString).deletingPathExtension
        let destinationURL = Self.tendiesStorageDirectory.appendingPathComponent(fileName)

        if sourceURL.standardizedFileURL.path != destinationURL.standardizedFileURL.path {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            } catch {
                let fileData = try Data(contentsOf: sourceURL)
                try fileData.write(to: destinationURL, options: .atomic)
            }
        }

        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw NSError(
                domain: "TendiesEngine",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "壁纸文件保存失败：\(destinationURL.path)"]
            )
        }

        // 解压到临时目录以检查内容
        let tempExtractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tendie_inspect_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempExtractDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempExtractDir)
        }

        let extractRC = destinationURL.path.withCString { arcC in
            tempExtractDir.path.withCString { dstC in
                al_zip_extract_all(arcC, dstC)
            }
        }

        guard extractRC == 0 else {
            throw NSError(
                domain: "TendiesEngine",
                code: Int(extractRC),
                userInfo: [NSLocalizedDescriptionKey: "解压 .tendies 压缩包失败（代码 \(extractRC)）"]
            )
        }

        // 分析文件结构
        var isContainer = false
        var unsafeContainer = false
        var descriptorCount = 0
        var posterType: TendiePosterType = .collections

        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: tempExtractDir,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        var candidateImages: [(url: URL, score: Int)] = []

        while let itemURL = enumerator?.nextObject() as? URL {
            let pathLower = itemURL.path.lowercased()
            let nameLower = itemURL.lastPathComponent.lowercased()

            if pathLower.contains("__macosx") || nameLower == ".ds_store" {
                continue
            }

            if pathLower.contains("/container/") || pathLower.hasSuffix("/container") {
                isContainer = true
                posterType = .container
                if nameLower.contains("pbfposterextensiondatastoresqlitedatabase.sqlite3") {
                    unsafeContainer = true
                }
            }

            if pathLower.contains("descriptor") || pathLower.contains("descriptors") {
                if pathLower.contains("video") || pathLower.contains("photos") {
                    posterType = .suggestedPhotos
                } else if pathLower.contains("mercury") {
                    posterType = .mercury
                } else if posterType != .container {
                    posterType = .collections
                }
            }

            // 通过查找 .wallpaper 或子描述项文件夹来统计描述项数量
            if nameLower.hasSuffix(".wallpaper") || nameLower == "wallpaper.plist" {
                descriptorCount += 1
            }

            // 查找预览图
            let ext = itemURL.pathExtension.lowercased()
            if ["heic", "png", "jpg", "jpeg"].contains(ext) {
                var score = 10
                if pathLower.contains("proxy") || pathLower.contains("adjusted") {
                    score += 90
                } else if pathLower.contains("background") || pathLower.contains("settling") {
                    score += 70
                } else if pathLower.contains("preview") || pathLower.contains("thumb") {
                    score += 50
                } else if pathLower.contains("asset.resource") {
                    score += 40
                }
                candidateImages.append((itemURL, score))
            }
        }

        if descriptorCount == 0 {
            descriptorCount = 1
        }

        // 挑选最佳预览图
        candidateImages.sort { $0.score > $1.score }
        var previewData: Data? = nil

        for candidate in candidateImages {
            if let img = UIImage(contentsOfFile: candidate.url.path) {
                let thumb = self.downsample(image: img, maxDimension: 600)
                if let jpeg = thumb.jpegData(compressionQuality: 0.85) {
                    previewData = jpeg
                    break
                }
            }
        }

        return TendieItem(
            name: baseName,
            fileName: fileName,
            relativePath: fileName,
            isContainer: isContainer,
            unsafeContainer: unsafeContainer,
            descriptorCount: descriptorCount,
            posterType: posterType,
            previewImageData: previewData,
            dateImported: Date(),
            isSelected: true
        )
    }

    // MARK: - 生成缩略图

    private func downsample(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - 自动检测 PosterBoard 容器

    public func detectPosterBoardContainer(pairingPath: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var outContainer: UnsafeMutablePointer<CChar>? = nil
                var outError: UnsafeMutablePointer<CChar>? = nil

                let rc = pairingPath.withCString { pairC in
                    "com.apple.PosterBoard".withCString { bundleC in
                        al_find_app_container(pairC, bundleC, nil, nil, &outContainer, &outError)
                    }
                }

                if rc == 0, let p = outContainer {
                    let containerStr = String(cString: p)
                    al_string_free(p)
                    continuation.resume(returning: containerStr)
                } else {
                    let errStr = outError.flatMap { p in
                        let s = String(cString: p)
                        al_string_free(p)
                        return s
                    } ?? "未能找到 PosterBoard 容器"
                    continuation.resume(throwing: NSError(
                        domain: "TendiesEngine",
                        code: Int(rc),
                        userInfo: [NSLocalizedDescriptionKey: errStr]
                    ))
                }
            }
        }
    }

    // MARK: - 通过隧道发送重启信号

    public func sendRespringSignal(pairingPath: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var outError: UnsafeMutablePointer<CChar>? = nil
                let rc = pairingPath.withCString { pC in
                    al_device_respring(pC, nil, nil, &outError)
                }
                if let p = outError {
                    al_string_free(p)
                }
                continuation.resume(returning: rc == 0)
            }
        }
    }

    // MARK: - 将 Tendies 刷入设备

    public func flashTendies(
        items: [TendieItem],
        containerPath: String,
        resetProtections: Bool,
        pairingPath: String,
        log: @escaping (String) -> Void,
        progress: @escaping (Double) -> Void
    ) async throws {
        guard !items.isEmpty else {
            log("⚠️ 没有选择要刷入的壁纸")
            return
        }

        var normalizedContainer = containerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedContainer.hasSuffix("/") {
            normalizedContainer = String(normalizedContainer.dropLast())
        }
        if normalizedContainer.isEmpty {
            throw NSError(
                domain: "TendiesEngine",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "必须提供 PosterBoard 容器路径。"]
            )
        }

        let majorVer = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let structVersion = (majorVer <= 16) ? 59 : 61
        let versionsToWrite: [Int] = [structVersion]

        log("🚀 开始向 \(normalizedContainer) 注入 PosterBoard 数据")
        log("ℹ️ 目标 PosterBoard 结构版本：\(structVersion)（iOS \(majorVer)）")

        let totalItems = Double(items.count)

        for (itemIndex, item) in items.enumerated() {
            log("\n📦 [\(itemIndex + 1)/\(items.count)] 正在处理「\(item.name)」…")

            let tempStageDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("tendie_flash_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempStageDir, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(at: tempStageDir)
            }

            let extractRC = item.fileURL.path.withCString { arcC in
                tempStageDir.path.withCString { dstC in
                    al_zip_extract_all(arcC, dstC)
                }
            }
            guard extractRC == 0 else {
                log("❌ 解压「\(item.name)」失败")
                continue
            }

            log("  🖼 正在定位壁纸描述项…")
            let descriptors = findDescriptorsWithExtensions(in: tempStageDir, defaultExt: item.posterType.extensionBundleId)
            log("  ✨ 找到 \(descriptors.count) 个待安装描述项")

            for (descIndex, descItem) in descriptors.enumerated() {
                let targetUUID = UUID().uuidString.uppercased()
                let randomizedID = Int.random(in: 10000...99999)
                log("  [\(descIndex + 1)/\(descriptors.count)] 描述项 \(targetUUID)（ID：\(randomizedID)），扩展：\(descItem.ext)…")

                // 更新 plist 中的标识符，确保索引唯一、不发生冲突
                updatePlistIdentifiers(in: descItem.url, randomizedID: randomizedID)

                for sVer in versionsToWrite {
                    // 主目标路径
                    let targetParentDir = "\(normalizedContainer)/Library/Application Support/PRBPosterExtensionDataStore/\(sVer)/Extensions/\(descItem.ext)/descriptors"
                    try await injectDescriptorFolder(
                        folderURL: descItem.url,
                        targetParentDir: targetParentDir,
                        destName: targetUUID,
                        pairingPath: pairingPath,
                        log: log
                    )

                    // iOS 18 及以上，Collections 已迁移到 com.apple.Posters.CollectionsPosterApp
                    if descItem.ext == "com.apple.WallpaperKit.CollectionsPoster" {
                        let modernParentDir = "\(normalizedContainer)/Library/Application Support/PRBPosterExtensionDataStore/\(sVer)/Extensions/com.apple.Posters.CollectionsPosterApp/descriptors"
                        try? await injectDescriptorFolder(
                            folderURL: descItem.url,
                            targetParentDir: modernParentDir,
                            destName: targetUUID,
                            pairingPath: pairingPath,
                            log: log
                        )
                    }
                }
            }

            progress(Double(itemIndex + 1) / (totalItems + 1))
        }

        // 始终强制刷新 PosterBoard 缓存并重置文件保护
        log("\n🔄 正在强制刷新 PosterBoard 缓存并重置文件保护…")
        let stagePrefDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tendie_pref_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: stagePrefDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: stagePrefDir)
        }

        let prefPlistURL = stagePrefDir.appendingPathComponent("com.apple.PosterBoard.unprotectedUserDefaults.plist")
        let prefDict: [String: Any] = [
            "PBF_RESET_FILE_PROTECTIONS": true,
            "PBF_LOCALE_DID_CHANGE": false,
            "PersistedPosterContainerBundleIdentifiers": [
                "com.apple.Posters.CollectionsPosterApp",
                "com.apple.WallpaperKit.CollectionsPoster"
            ],
            "CompletedPosterBundleIdentifierMigrations": [
                "com.apple.Posters.UnityPosterApp.ExtragalacticPoster",
                "com.apple.Posters.WeatherPosterApp.WeatherPoster",
                "com.apple.Posters.UnityPosterApp.Unity2025Poster",
                "com.apple.Posters.UnityPosterApp.UnityPosterExtension",
                "com.apple.Posters.UnityPosterApp.RhizomePoster",
                "com.apple.Posters.KaleidoscopePosterApp.KaleidoscopePoster"
            ]
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: prefDict, format: .binary, options: 0)
        try plistData.write(to: prefPlistURL)

        let targetPrefDir = "\(normalizedContainer)/Library/Preferences"
        try await writeDirectoryTree(
            sourceBaseDir: stagePrefDir,
            targetBaseDir: targetPrefDir,
            pairingPath: pairingPath,
            log: log
        )

        // 同时写入 mobile 全局偏好设置，供系统守护进程查询
        let mobilePrefDir = "/var/mobile/Library/Preferences"
        try? await writeDirectoryTree(
            sourceBaseDir: stagePrefDir,
            targetBaseDir: mobilePrefDir,
            pairingPath: pairingPath,
            log: log
        )
        log("✅ PosterBoard 偏好设置已就绪，等待重载")

        progress(1.0)
        log("\n🎉 所有壁纸注入成功！请打开锁屏设置，或长按锁屏界面选择新壁纸。")
    }

    // MARK: - 目录树写入工具

    private func writeDirectoryTree(
        sourceBaseDir: URL,
        targetBaseDir: String,
        pairingPath: String,
        log: @escaping (String) -> Void
    ) async throws {
        let fileManager = FileManager.default

        // 收集所有包含文件的目录
        var dirsToWrite: Set<URL> = []
        if let enumerator = fileManager.enumerator(
            at: sourceBaseDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            while let itemURL = enumerator.nextObject() as? URL {
                let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if !isDir {
                    dirsToWrite.insert(itemURL.deletingLastPathComponent())
                }
            }
        }

        // 若没有子文件，则在源目录非空时直接写入该目录
        if dirsToWrite.isEmpty {
            let files = (try? fileManager.contentsOfDirectory(atPath: sourceBaseDir.path)) ?? []
            if !files.isEmpty {
                dirsToWrite.insert(sourceBaseDir)
            }
        }

        let canonicalSource = sourceBaseDir.resolvingSymlinksInPath().path

        for dir in dirsToWrite {
            let canonicalDir = dir.resolvingSymlinksInPath().path
            var relPath = ""
            if canonicalDir.hasPrefix(canonicalSource) {
                relPath = String(canonicalDir.dropFirst(canonicalSource.count))
                relPath = relPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }

            let targetDir: String
            if relPath.isEmpty {
                targetDir = targetBaseDir
            } else {
                targetDir = "\(targetBaseDir)/\(relPath)"
            }

            log("  正在写入 \(targetDir)…")

            var writeOk = false
            var errDesc: String? = nil

            await withCheckedContinuation { cont in
                DispatchQueue.global(qos: .userInitiated).async {
                    var outError: UnsafeMutablePointer<CChar>? = nil
                    let rc = pairingPath.withCString { pairC in
                        dir.path.withCString { srcC in
                            targetDir.withCString { tgtC in
                                al_exploit_write_dir(pairC, srcC, tgtC, { _, msg in
                                    guard let msg = msg else { return }
                                    let line = String(cString: msg)
                                    DispatchQueue.main.async {
                                        AppViewModel.shared?.tendiesFlashLog.append("    " + line)
                                    }
                                }, nil, &outError)
                            }
                        }
                    }
                    if let p = outError {
                        errDesc = String(cString: p)
                        al_string_free(p)
                    }
                    writeOk = (rc == 0)
                    cont.resume()
                }
            }

            if !writeOk {
                throw NSError(
                    domain: "TendiesEngine",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "目录写入失败：\(errDesc ?? "漏洞利用错误")"]
                )
            }
        }
    }

    // MARK: - Plist 标识符随机化（与 Nugget 实现一致）

    private func updatePlistIdentifiers(in folderURL: URL, randomizedID: Int) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        while let fileURL = enumerator.nextObject() as? URL {
            let fileName = fileURL.lastPathComponent

            if fileName == "com.apple.posterkit.provider.descriptor.identifier" {
                try? "\(randomizedID)".data(using: .utf8)?.write(to: fileURL)
            } else if fileName == "com.apple.posterkit.provider.contents.userInfo" {
                if let data = try? Data(contentsOf: fileURL),
                   var plist = (try? PropertyListSerialization.propertyList(from: data, options: .mutableContainers, format: nil)) as? [String: Any] {
                    plist["wallpaperRepresentingIdentifier"] = randomizedID
                    if let updated = try? PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0) {
                        try? updated.write(to: fileURL)
                    }
                }
            } else if fileName.hasSuffix("Wallpaper.plist") {
                if let data = try? Data(contentsOf: fileURL),
                   var plist = (try? PropertyListSerialization.propertyList(from: data, options: .mutableContainers, format: nil)) as? [String: Any] {
                    plist["identifier"] = randomizedID
                    if let updated = try? PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0) {
                        try? updated.write(to: fileURL)
                    }
                }
            }
        }
    }

    // MARK: - 文件夹注入工具（通过 AirTraffic 单次原子移动）

    private func injectDescriptorFolder(
        folderURL: URL,
        targetParentDir: String,
        destName: String,
        pairingPath: String,
        log: @escaping (String) -> Void
    ) async throws {
        log("  📦 正在将「\(destName)」注入 \(targetParentDir)…")
        var errDesc: String? = nil
        let ok: Bool = await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                var outError: UnsafeMutablePointer<CChar>? = nil
                let rc = pairingPath.withCString { pairC in
                    folderURL.path.withCString { folderC in
                        targetParentDir.withCString { parentC in
                            destName.withCString { destC in
                                al_exploit_inject_folder(
                                    pairC,
                                    folderC,
                                    parentC,
                                    destC,
                                    { _, msg in
                                        guard let msg = msg else { return }
                                        let line = String(cString: msg)
                                        DispatchQueue.main.async {
                                            AppViewModel.shared?.tendiesFlashLog.append("    " + line)
                                        }
                                    },
                                    nil,
                                    &outError
                                )
                            }
                        }
                    }
                }
                if let p = outError {
                    errDesc = String(cString: p)
                    al_string_free(p)
                }
                cont.resume(returning: rc == 0)
            }
        }

        if !ok {
            throw NSError(
                domain: "TendiesEngine",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "描述项注入失败：\(errDesc ?? "漏洞利用错误")"]
            )
        }
    }

    // MARK: - 按目标扩展查找描述项

    private func findDescriptorsWithExtensions(in rootURL: URL, defaultExt: String) -> [(ext: String, url: URL)] {
        let fileManager = FileManager.default
        var results: [(ext: String, url: URL)] = []

        // 1. 检查标准容器结构
        let containerFolder = rootURL.appendingPathComponent("container")
        let searchRoots = fileManager.fileExists(atPath: containerFolder.path) ? [containerFolder, rootURL] : [rootURL]

        for sRoot in searchRoots {
            let extensionsDir = sRoot.appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore/61/Extensions")
            if fileManager.fileExists(atPath: extensionsDir.path) {
                if let extEntries = try? fileManager.contentsOfDirectory(at: extensionsDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                    for extFolder in extEntries {
                        let descDir = extFolder.appendingPathComponent("descriptors")
                        if fileManager.fileExists(atPath: descDir.path),
                           let descEntries = try? fileManager.contentsOfDirectory(at: descDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                            for d in descEntries where (try? d.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false {
                                if !d.lastPathComponent.hasPrefix(".") && d.lastPathComponent != "__MACOSX" {
                                    results.append((ext: extFolder.lastPathComponent, url: d))
                                }
                            }
                        }
                    }
                }
            }
        }
        if !results.isEmpty {
            return results
        }

        // 2. 检查 "descriptors" 或 "descriptor" 文件夹
        for folderName in ["descriptors", "descriptor", "ordered-descriptors", "ordered-descriptor"] {
            let descDir = rootURL.appendingPathComponent(folderName)
            if fileManager.fileExists(atPath: descDir.path),
               let contents = try? fileManager.contentsOfDirectory(at: descDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for d in contents where (try? d.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false {
                    if !d.lastPathComponent.hasPrefix(".") && d.lastPathComponent != "__MACOSX" {
                        results.append((ext: defaultExt, url: d))
                    }
                }
            }
        }
        if !results.isEmpty {
            return results
        }

        // 3. 检查 "video-descriptors" 或 "video-descriptor"
        for folderName in ["video-descriptors", "video-descriptor"] {
            let descDir = rootURL.appendingPathComponent(folderName)
            if fileManager.fileExists(atPath: descDir.path),
               let contents = try? fileManager.contentsOfDirectory(at: descDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for d in contents where (try? d.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false {
                    if !d.lastPathComponent.hasPrefix(".") && d.lastPathComponent != "__MACOSX" {
                        results.append((ext: "com.apple.PhotosUIPrivate.PhotosPosterProvider", url: d))
                    }
                }
            }
        }
        if !results.isEmpty {
            return results
        }

        // 4. 检查根目录是否包含 versions 或 Wallpaper.plist
        if fileManager.fileExists(atPath: rootURL.appendingPathComponent("versions").path) ||
           fileManager.fileExists(atPath: rootURL.appendingPathComponent("Wallpaper.plist").path) ||
           fileManager.fileExists(atPath: rootURL.appendingPathComponent("com.apple.posterkit.provider.descriptor.identifier").path) {
            return [(ext: defaultExt, url: rootURL)]
        }

        // 5. 兜底：扫描任意含 "versions" 或 UUID 命名的子文件夹
        if let topLevel = try? fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for sub in topLevel where (try? sub.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false {
                if !sub.lastPathComponent.hasPrefix(".") && sub.lastPathComponent != "__MACOSX" {
                    let hasVersions = fileManager.fileExists(atPath: sub.appendingPathComponent("versions").path)
                    let isUUID = UUID(uuidString: sub.lastPathComponent) != nil
                    if hasVersions || isUUID {
                        results.append((ext: defaultExt, url: sub))
                    }
                }
            }
        }

        return results.isEmpty ? [(ext: defaultExt, url: rootURL)] : results
    }
}
