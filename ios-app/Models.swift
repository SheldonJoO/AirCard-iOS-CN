import UIKit
import CoreGraphics
import SwiftUI
import PhotosUI
import CoreTransferable

// MARK: - 数据模型

struct CardItem: Identifiable, Equatable {
    let id: String
    var isSelected: Bool = true
    var customImageData: Data? = nil  // 主 PNG 数据（1536x969）
    var customImage: UIImage? = nil   // 用于快速显示的缓存 UIImage

    var uiImage: UIImage? {
        customImage ?? (customImageData.flatMap { UIImage(data: $0) })
    }

    /// 规范化并清理卡片标识符：去除路径、扩展名（.pkpass、.cache）、
    /// 引号与空白字符，并校验长度与格式。
    static func cleanCardId(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "'\",()<>;[]{}"))
        if s.contains("/") {
            s = (s as NSString).lastPathComponent
        }
        for ext in [".pkpass", ".cache", ".pkcache"] {
            if s.hasSuffix(ext) {
                s = String(s.dropLast(ext.count))
            }
        }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "'\",()<>;[]{}. "))
        if s.count >= 20 && s.count <= 64 && !s.contains("/") {
            if s.count == 36 && s.filter({ $0 == "-" }).count == 4 {
                return nil // UUID format, not a card hash
            }
            return s
        }
        return nil
    }

    static func == (lhs: CardItem, rhs: CardItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.isSelected == rhs.isSelected &&
        lhs.customImage === rhs.customImage &&
        (lhs.customImageData?.count == rhs.customImageData?.count)
    }
}


enum AppTab: String, CaseIterable, Identifiable {
    case pairing = "配对"
    case walletCards = "钱包卡片"
    case passcodeThemes = "密码盘"
    case wallpapers = "壁纸"
    var id: String { rawValue }
}

struct PasscodeThemeInfo: Identifiable {
    var id: String { filePath }
    let name: String
    let filePath: String
    let fileCount: Int
    let keysPreview: [String: UIImage]
    var rawKeyData: [String: Data] = [:]
}

enum CreatorMode: String, CaseIterable, Identifiable {
    case applyTheme = "应用 .passthm"
    case themeCreator = "制作主题"
    var id: String { rawValue }
}

enum SliceMode: String, CaseIterable, Identifiable {
    case posterSlice = "海报切图"
    case individualKeys = "单个按键"
    var id: String { rawValue }
}

enum PasscodeLanguageTarget: String, CaseIterable, Identifiable {
    case all = "所有语言（通用）"
    case uk = "乌克兰语（uk）"
    case ru = "俄语（ru）"
    case en = "英语（en）"
    case other = "其他 / 兜底"
    case es = "西班牙语（es）"
    case de = "德语（de）"
    case fr = "法语（fr）"
    case pl = "波兰语（pl）"
    case it = "意大利语（it）"
    case pt = "葡萄牙语（pt）"
    case tr = "土耳其语（tr）"
    case ja = "日语（ja）"
    case ko = "韩语（ko）"
    case zh = "中文（zh）"
    case ar = "阿拉伯语（ar）"
    case he = "希伯来语（he）"

    var id: String { rawValue }

    var code: String {
        switch self {
        case .all: return "all"
        case .uk: return "uk"
        case .ru: return "ru"
        case .en: return "en"
        case .other: return "other"
        case .es: return "es"
        case .de: return "de"
        case .fr: return "fr"
        case .pl: return "pl"
        case .it: return "it"
        case .pt: return "pt"
        case .tr: return "tr"
        case .ja: return "ja"
        case .ko: return "ko"
        case .zh: return "zh"
        case .ar: return "ar"
        case .he: return "he"
        }
    }
}

enum PasscodeBoldTarget: String, CaseIterable, Identifiable {
    case both = "通用（常规 + 粗体）"
    case boldOnly = "仅粗体（快速）"
    case regularOnly = "仅常规字体（快速）"

    var id: String { rawValue }

    var code: String {
        switch self {
        case .both: return "both"
        case .boldOnly: return "bold"
        case .regularOnly: return "regular"
        }
    }
}

enum KeypadLocales {
    static let all: [String] = [
        "en", "other", "ru", "uk", "es", "fr", "de", "it", "pt", "tr", "pl", "nl", "ja", "ko", "zh", "ar", "he"
    ]

    static let cyrillicRU: [String: String] = [
        "2": "А Б В Г",
        "3": "Д Е Ж З",
        "4": "И Й К Л",
        "5": "М Н О П",
        "6": "Р С Т У",
        "7": "Ф Х Ц Ч",
        "8": "Ш Щ Ъ Ы",
        "9": "Ь Э Ю Я",
    ]

    static let cyrillicUK: [String: String] = [
        "2": "А Б В Г",
        "3": "Д Е Ж З",
        "4": "І Ї Й К",
        "5": "Л М Н О",
        "6": "П Р С Т",
        "7": "У Ф Х Ц",
        "8": "Ч Ш Щ Ь",
        "9": "Ю Я",
    ]
}

// MARK: - 拨号键盘布局（与 AirCard 完全一致）

struct KeypadButtonGeometry: Identifiable {
    var id: String { digit }
    let digit: String
    let letters: String
    let row: Int
    let col: Int
}

enum KeypadLayout {
    static let buttonDiameter: CGFloat = 75.0
    static let gridWidth: CGFloat = 305.0
    static let gridHeight: CGFloat = 1148.0 / 3.0   // ≈382.67
    static let colWidth: CGFloat = 305.0 / 3.0        // ≈101.67
    static let rowHeight: CGFloat = 1148.0 / 12.0     // ≈95.67

    static let allButtons: [KeypadButtonGeometry] = [
        KeypadButtonGeometry(digit: "1", letters: "",        row: 0, col: 0),
        KeypadButtonGeometry(digit: "2", letters: "A B C",  row: 0, col: 1),
        KeypadButtonGeometry(digit: "3", letters: "D E F",  row: 0, col: 2),
        KeypadButtonGeometry(digit: "4", letters: "G H I",  row: 1, col: 0),
        KeypadButtonGeometry(digit: "5", letters: "J K L",  row: 1, col: 1),
        KeypadButtonGeometry(digit: "6", letters: "M N O",  row: 1, col: 2),
        KeypadButtonGeometry(digit: "7", letters: "P Q R S",row: 2, col: 0),
        KeypadButtonGeometry(digit: "8", letters: "T U V",  row: 2, col: 1),
        KeypadButtonGeometry(digit: "9", letters: "W X Y Z",row: 2, col: 2),
        KeypadButtonGeometry(digit: "0", letters: "+",      row: 3, col: 1),
    ]

    static let subtexts: [String: String] = [
        "0": "+",  "1": "",      "2": "A B C",  "3": "D E F",
        "4": "G H I", "5": "J K L", "6": "M N O",
        "7": "P Q R S", "8": "T U V", "9": "W X Y Z"
    ]
}

// MARK: - 安全图像处理引擎（iOS：基于 UIGraphicsImageRenderer，自动纠正方向并降采样）

enum ImageEngine {

    /// 使用 ImageIO 直接按缩小后的尺寸解码图片数据。
    /// 绝不把 4800 万像素的完整解压位图载入内存，以避免 Jetsam 触发的 OOM 崩溃。
    static func safeImageFromData(_ data: Data, maxDimension: CGFloat = 2048) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return UIImage(data: data).map { normalizeAndDownsample($0, maxDimension: maxDimension) }
        }
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(data: data).map { normalizeAndDownsample($0, maxDimension: maxDimension) }
    }

    /// 校正图片方向，并对超大相机照片（4800 万像素 / RAW）降采样，
    /// 以避免 iOS 上的 Jetsam OOM 崩溃。
    static func normalizeAndDownsample(_ image: UIImage, maxDimension: CGFloat = 2048) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }

        let scale = min(1.0, maxDimension / max(size.width, size.height))
        let targetSize = CGSize(width: max(1, floor(size.width * scale)),
                                height: max(1, floor(size.height * scale)))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// 将图片缩放到指定尺寸。
    static func resizeImage(_ image: UIImage, targetSize: CGSize) -> Data? {
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0 else { return nil }
        let scale = max(targetSize.width / imgSize.width, targetSize.height / imgSize.height)
        let scaledSize = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
        let origin = CGPoint(x: (targetSize.width - scaledSize.width) / 2,
                             y: (targetSize.height - scaledSize.height) / 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let out = renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
        return out.pngData()
    }

    /// 将图片缩放为精确的 1536×969 PNG —— 用于钱包卡面预览与主存储。
    static func prepareCardImage(from image: UIImage) -> Data? {
        let normalized = normalizeAndDownsample(image, maxDimension: 2560)
        return resizeImage(normalized, targetSize: CGSize(width: 1536, height: 969))
    }

    /// 生成 Apple 钱包卡片皮肤所需的全部精确分辨率文件。
    /// 完美适配标准版、Plus、Pro 与 Pro Max 屏幕。
    /// 输出 cardBackgroundCombined、diffuse、background 与 strip，覆盖所有 Apple Pay 卡片。
    static func prepareAllCardSkins(from image: UIImage) -> [String: Data] {
        let normalized = normalizeAndDownsample(image, maxDimension: 2560)
        var skins: [String: Data] = [:]

        let bg3x = resizeImage(normalized, targetSize: CGSize(width: 1536, height: 969))
        let bg2x = resizeImage(normalized, targetSize: CGSize(width: 1024, height: 646))

        if let data3x = bg3x {
            skins["cardBackgroundCombined@3x.png"] = data3x
            skins["diffuse@3x.png"] = data3x
            skins["background@3x.png"] = data3x
            skins["strip@3x.png"] = data3x
        }
        if let data2x = bg2x {
            skins["cardBackgroundCombined@2x.png"] = data2x
            skins["diffuse@2x.png"] = data2x
            skins["background@2x.png"] = data2x
            skins["strip@2x.png"] = data2x
        }

        // 向量 PDF 变体，用于 Suica、Pasmo、ICOCA 等交通卡
        let pdfRect = CGRect(origin: .zero, size: CGSize(width: 1536, height: 969))
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pdfRect)
        let pdfData = pdfRenderer.pdfData { ctx in
            ctx.beginPage()
            normalized.draw(in: pdfRect)
        }
        skins["cardBackgroundCombined.pdf"] = pdfData
        skins["background.pdf"] = pdfData
        skins["strip.pdf"] = pdfData

        return skins
    }


    /// 使用 UIGraphicsImageRenderer 安全地把海报图切片成每个按键的小图。
    /// 不会因色彩空间、图片方向或内存上限而崩溃。
    static func slicePoster(
        image: UIImage,
        zoom: CGFloat = 1.0,
        offset: CGPoint = .zero,
        maskToCircles: Bool = false
    ) -> [String: UIImage] {
        let normalized = normalizeAndDownsample(image, maxDimension: 2048)
        let imgW = normalized.size.width
        let imgH = normalized.size.height
        guard imgW > 0, imgH > 0 else { return [:] }

        let gridW: CGFloat = 915.0
        let gridH: CGFloat = 1148.0
        let colW: CGFloat  = 305.0
        let rowH: CGFloat  = 287.0

        let imgAspect  = imgW / imgH
        let gridAspect = gridW / gridH

        let safeZoom = max(0.2, min(5.0, zoom))
        let scaledW: CGFloat
        let scaledH: CGFloat
        if imgAspect > gridAspect {
            scaledH = gridH * safeZoom
            scaledW = scaledH * imgAspect
        } else {
            scaledW = gridW * safeZoom
            scaledH = scaledW / imgAspect
        }

        let imageX = (gridW - scaledW) / 2.0 + offset.x * 3.0
        let imageY = (gridH - scaledH) / 2.0 + offset.y * 3.0

        var results: [String: UIImage] = [:]

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false

        for btn in KeypadLayout.allButtons {
            if maskToCircles {
                // 圆形按键模式：与按键直径精确匹配的圆形切片（225×225）
                let cellX: CGFloat = CGFloat(btn.col) * colW
                let cellY: CGFloat = CGFloat(btn.row) * rowH
                let btnCenterX = cellX + colW / 2.0
                let btnCenterY = cellY + rowH / 2.0
                let d: CGFloat = 225.0
                let circleOriginX = btnCenterX - d / 2.0
                let circleOriginY = btnCenterY - d / 2.0

                let tileSize = CGSize(width: d, height: d)
                let destX = imageX - circleOriginX
                let destY = imageY - circleOriginY

                let renderer = UIGraphicsImageRenderer(size: tileSize, format: format)
                let tile = autoreleasepool {
                    renderer.image { _ in
                        let circlePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: d, height: d))
                        circlePath.addClip()
                        normalized.draw(in: CGRect(x: destX, y: destY, width: scaledW, height: scaledH))
                    }
                }
                results[btn.digit] = tile
            } else {
                // 无缝海报模式：不裁切的网格切片（305×287，按键 0 为 915×287）
                let isZeroSeamless = (btn.digit == "0")
                let tileW: CGFloat = isZeroSeamless ? gridW : colW
                let tileH: CGFloat = rowH
                let tileSize = CGSize(width: tileW, height: tileH)

                let cellX: CGFloat = isZeroSeamless ? 0.0 : CGFloat(btn.col) * colW
                let cellY: CGFloat = CGFloat(btn.row) * rowH

                let destX = imageX - cellX
                let destY = imageY - cellY

                let renderer = UIGraphicsImageRenderer(size: tileSize, format: format)
                let tile = autoreleasepool {
                    renderer.image { _ in
                        normalized.draw(in: CGRect(x: destX, y: destY, width: scaledW, height: scaledH))
                    }
                }
                results[btn.digit] = tile
            }
        }

        return results
    }

    /// 安全地把图片裁成圆形（用于单个按键模式）。
    static func cropToCircle(
        image: UIImage,
        targetSize: CGSize = CGSize(width: 225, height: 225),
        circleDiameter: CGFloat = 222.0,
        zoom: CGFloat = 1.0,
        offset: CGPoint = .zero
    ) -> UIImage? {
        let normalized = normalizeAndDownsample(image, maxDimension: 1024)
        let imgW = normalized.size.width
        let imgH = normalized.size.height
        guard imgW > 0, imgH > 0 else { return nil }

        let safeZoom = max(0.2, min(5.0, zoom))
        let baseScale = max(circleDiameter / imgW, circleDiameter / imgH) * safeZoom
        let scaledW = imgW * baseScale
        let scaledH = imgH * baseScale

        let circleX = (targetSize.width  - circleDiameter) / 2.0
        let circleY = (targetSize.height - circleDiameter) / 2.0

        let destX = circleX + (circleDiameter - scaledW) / 2.0 + offset.x * 3.0
        let destY = circleY + (circleDiameter - scaledH) / 2.0 + offset.y * 3.0

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { ctx in
            let circlePath = UIBezierPath(ovalIn: CGRect(x: circleX, y: circleY,
                                                         width: circleDiameter, height: circleDiameter))
            circlePath.addClip()
            normalized.draw(in: CGRect(x: destX, y: destY, width: scaledW, height: scaledH))
        }
    }

    static func pngData(from image: UIImage) -> Data? {
        image.pngData()
    }
}

// MARK: - PhotosPickerItem 通用图片加载器

extension PhotosPickerItem {
    /// 从照片选择器条目加载 UIImage，安全处理 HEIC、实况照片、ProRAW 与 iCloud 下载。
    func loadUIImage(maxDimension: CGFloat = 2048) async -> UIImage? {
        // 1. Transferable DataRepresentation（自动转换为标准格式）
        struct ImageTransferable: Transferable {
            let data: Data
            static var transferRepresentation: some TransferRepresentation {
                DataRepresentation(importedContentType: .image) { data in
                    ImageTransferable(data: data)
                }
            }
        }
        if let result = try? await self.loadTransferable(type: ImageTransferable.self) {
            if let img = ImageEngine.safeImageFromData(result.data, maxDimension: maxDimension) {
                return img
            }
        }

        // 2. 直接读取原始数据
        if let data = try? await self.loadTransferable(type: Data.self) {
            if let img = ImageEngine.safeImageFromData(data, maxDimension: maxDimension) {
                return img
            }
        }

        // 3. 文件形式兜底（适合相机胶卷中的大图）
        struct FileImageTransferable: Transferable {
            let url: URL
            static var transferRepresentation: some TransferRepresentation {
                FileRepresentation(importedContentType: .image) { received in
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString + "_" + received.file.lastPathComponent)
                    try? FileManager.default.copyItem(at: received.file, to: tmp)
                    return FileImageTransferable(url: tmp)
                }
            }
        }
        if let fileResult = try? await self.loadTransferable(type: FileImageTransferable.self) {
            defer { try? FileManager.default.removeItem(at: fileResult.url) }
            if let data = try? Data(contentsOf: fileResult.url),
               let img = ImageEngine.safeImageFromData(data, maxDimension: maxDimension) {
                return img
            }
        }

        return nil
    }
}

// MARK: - PasscodeThemePackager（基于 Foundation 的原生 Swift 打包）

enum PasscodeThemePackager {

    /// 在内存中构建 .passthm 压缩包，并返回其 Data。
    static func buildPassthm(
        keys: [String: UIImage],
        telephonyVersion: String = "all",
        language: PasscodeLanguageTarget = .all,
        bold: PasscodeBoldTarget = .both
    ) throws -> Data {
        var zipData = Data()
        var centralDirectory = Data()
        var centralDirCount: UInt16 = 0

        func addEntry(name: String, content: Data) {
            guard let nameData = name.data(using: .utf8) else { return }
            let crc = crc32(content)
            let localHeader = makeLocalFileHeader(name: nameData, content: content, crc: crc)
            let offset = UInt32(zipData.count)
            zipData.append(localHeader)
            zipData.append(content)
            centralDirectory.append(
                makeCentralDirEntry(name: nameData, content: content, crc: crc, offset: offset))
            centralDirCount += 1
        }

        let targetVers: [String]
        if telephonyVersion == "all" || telephonyVersion.isEmpty {
            targetVers = ["TelephonyUI-10", "TelephonyUI-9", "TelephonyUI-8"]
        } else {
            targetVers = [telephonyVersion]
        }

        let langs: [String]
        if language == .all {
            langs = KeypadLocales.all
        } else {
            langs = language.code == "other" ? ["other"] : [language.code, "other"]
        }

        let boldSuffixes: [String]
        switch bold {
        case .both: boldSuffixes = ["", "-bold"]
        case .boldOnly: boldSuffixes = ["-bold"]
        case .regularOnly: boldSuffixes = [""]
        }

        for ver in targetVers {
            addEntry(name: "\(ver)/_big", content: Data())

            for (digit, image) in keys {
                guard let pngData = image.pngData() else { continue }
                let stdSubtext = KeypadLayout.subtexts[digit] ?? ""

                for lang in langs {
                    for bld in boldSuffixes {
                        // 1. Blank subtext
                        addEntry(name: "\(ver)/\(lang)-\(digit)---white\(bld).png", content: pngData)

                        // 2. Standard Latin subtext
                        if !stdSubtext.isEmpty {
                            addEntry(name: "\(ver)/\(lang)-\(digit)-\(stdSubtext)--white\(bld).png", content: pngData)
                            let noSpace = stdSubtext.replacingOccurrences(of: " ", with: "")
                            if noSpace != stdSubtext {
                                addEntry(name: "\(ver)/\(lang)-\(digit)-\(noSpace)--white\(bld).png", content: pngData)
                            }
                        }

                        // 3. Cyrillic subtexts
                        if (lang == "ru" || language == .all), let ruSub = KeypadLocales.cyrillicRU[digit] {
                            addEntry(name: "\(ver)/\(lang)-\(digit)-\(ruSub)--white\(bld).png", content: pngData)
                        }
                        if (lang == "uk" || language == .all), let ukSub = KeypadLocales.cyrillicUK[digit] {
                            addEntry(name: "\(ver)/\(lang)-\(digit)-\(ukSub)--white\(bld).png", content: pngData)
                        }
                    }
                }
            }
        }

        // End of central directory record
        let cdOffset = UInt32(zipData.count)
        let cdSize   = UInt32(centralDirectory.count)
        zipData.append(centralDirectory)
        zipData.append(makeEndRecord(count: centralDirCount, size: cdSize, offset: cdOffset))
        return zipData
    }

    static func buildPassthm(keys: [String: UIImage]) throws -> Data {
        try buildPassthm(keys: keys, telephonyVersion: "all", language: .all, bold: .both)
    }

    // MARK: - Zip 底层构造

    private static func makeLocalFileHeader(name: Data, content: Data, crc: UInt32) -> Data {
        var d = Data()
        d.appendLE32(0x04034b50)   // 本地文件头签名
        d.appendLE16(20)           // 所需版本：2.0
        d.appendLE16(0)            // 标志位
        d.appendLE16(0)            // 压缩方式：仅存储
        d.appendLE16(0)            // 最后修改时间
        d.appendLE16(0)            // 最后修改日期
        d.appendLE32(crc)
        d.appendLE32(UInt32(content.count))   // 压缩后大小
        d.appendLE32(UInt32(content.count))   // 未压缩大小
        d.appendLE16(UInt16(name.count))
        d.appendLE16(0)            // 扩展字段长度
        d.append(name)
        return d
    }

    private static func makeCentralDirEntry(
        name: Data, content: Data, crc: UInt32, offset: UInt32
    ) -> Data {
        var d = Data()
        d.appendLE32(0x02014b50)   // 中央目录文件头签名
        d.appendLE16(20)           // 创建版本
        d.appendLE16(20)           // Version needed
        d.appendLE16(0)            // 标志位
        d.appendLE16(0)            // 压缩方式：仅存储
        d.appendLE16(0)            // 最后修改时间
        d.appendLE16(0)            // 最后修改日期
        d.appendLE32(crc)
        d.appendLE32(UInt32(content.count))
        d.appendLE32(UInt32(content.count))
        d.appendLE16(UInt16(name.count))
        d.appendLE16(0)            // 扩展字段长度
        d.appendLE16(0)            // 文件注释长度
        d.appendLE16(0)            // 起始磁盘编号
        d.appendLE16(0)            // 内部文件属性
        d.appendLE32(0)            // 外部文件属性
        d.appendLE32(offset)       // 本地文件头的相对偏移
        d.append(name)
        return d
    }

    private static func makeEndRecord(count: UInt16, size: UInt32, offset: UInt32) -> Data {
        var d = Data()
        d.appendLE32(0x06054b50)   // 中央目录结束标记
        d.appendLE16(0)            // 磁盘编号
        d.appendLE16(0)            // 中央目录起始磁盘
        d.appendLE16(count)
        d.appendLE16(count)
        d.appendLE32(size)
        d.appendLE32(offset)
        d.appendLE16(0)            // 注释长度
        return d
    }

    /// CRC-32（ISO 3309 / ITU-T V.42）。
    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            var b = UInt32(byte)
            for _ in 0..<8 {
                let mixed = (crc ^ b) & 1
                crc >>= 1
                if mixed != 0 { crc ^= 0xEDB8_8320 }
                b >>= 1
            }
        }
        return ~crc
    }
}

private extension Data {
    mutating func appendLE16(_ v: UInt16) {
        var x = v.littleEndian
        Swift.withUnsafeBytes(of: &x) { append(contentsOf: $0) }
    }
    mutating func appendLE32(_ v: UInt32) {
        var x = v.littleEndian
        Swift.withUnsafeBytes(of: &x) { append(contentsOf: $0) }
    }
}

// MARK: - PasscodeThemeReader（.passthm → 按键图片）

import AirliftFFI

enum PasscodeThemeReader {

    /// 从 .passthm 压缩包中提取按键图片。
    /// 返回字典 [数字 → UIImage]、原始数据字典 [数字 → Data] 以及文件总数。
    static func inspect(url: URL) -> (keys: [String: UIImage], rawData: [String: Data], fileCount: Int)? {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("airlift_inspect_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. 通过 Rust 的 al_passthm_extract 解压（支持 deflate 与 store 两种条目）
        let rc = url.path.withCString { arcC in
            tempDir.path.withCString { dstC in
                al_passthm_extract(arcC, dstC)
            }
        }
        guard rc == 0 else { return nil }

        let files = (FileManager.default.subpaths(atPath: tempDir.path) ?? [])
        guard !files.isEmpty else { return nil }

        var keys: [String: UIImage] = [:]
        var rawData: [String: Data] = [:]
        var fileCount = 0

        for file in files {
            guard !file.hasPrefix("."), !file.contains("__MACOSX") else { continue }
            let lower = file.lowercased()
            guard lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") else { continue }

            fileCount += 1
            let filename = (file as NSString).lastPathComponent
            if let digit = extractDigit(from: filename) {
                if keys[digit] == nil {
                    let filePath = tempDir.appendingPathComponent(file).path
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                        rawData[digit] = data
                        if let img = ImageEngine.safeImageFromData(data, maxDimension: 512) {
                            keys[digit] = img
                        }
                    }
                }
            }
        }

        return keys.isEmpty ? nil : (keys, rawData, fileCount)
    }

    /// 按 AirCard 的正则逻辑从主题文件中提取数字
    static func extractDigit(from filename: String) -> String? {
        let stem = (filename as NSString).deletingPathExtension
        let stemClean = stem
            .replacingOccurrences(of: "--white", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "-white", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "@3x", with: "")
            .replacingOccurrences(of: "@2x", with: "")

        // 1. AirCard 匹配模式：(?:^[a-zA-Z]+-)?([0-9*#])(?:-([^-\n]+))?
        if let regex = try? NSRegularExpression(pattern: #"(?:^[a-zA-Z]+-)?([0-9*#])"#, options: .caseInsensitive) {
            let nsString = stemClean as NSString
            let match = regex.firstMatch(in: stemClean, range: NSRange(location: 0, length: nsString.length))
            if let match = match, match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                if range.location != NSNotFound {
                    let d = nsString.substring(with: range)
                    if "0123456789".contains(d) { return d }
                }
            }
        }

        // 2. 兜底：在文件名中查找单个数字
        for ch in stemClean {
            if "0123456789".contains(ch) { return String(ch) }
        }
        return nil
    }
}
