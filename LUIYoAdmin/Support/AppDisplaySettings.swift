import SwiftUI
import CoreText

// 全局显示设置：字体大小、布局疏密、自定义字体
class AppDisplaySettings: ObservableObject {
    @Published var fontSize: DeviceFontSize {
        didSet { save() }
    }
    @Published var density: DeviceDensity {
        didSet { save() }
    }
    @Published var customFontName: String? {
        didSet { save() }
    }
    @Published var importedFonts: [String] {
        didSet { save() }
    }

    private let fontSizeKey = "appFontSize"
    private let densityKey = "appDensity"
    private let customFontKey = "appCustomFont"
    private let importedFontsKey = "appImportedFonts"

    init() {
        let fs = UserDefaults.standard.string(forKey: fontSizeKey) ?? DeviceFontSize.standard.rawValue
        self.fontSize = DeviceFontSize(rawValue: fs) ?? .standard
        let dn = UserDefaults.standard.string(forKey: densityKey) ?? DeviceDensity.standard.rawValue
        self.density = DeviceDensity(rawValue: dn) ?? .standard
        let cf = UserDefaults.standard.string(forKey: customFontKey)
        self.customFontName = (cf?.isEmpty == false) ? cf : nil
        self.importedFonts = UserDefaults.standard.stringArray(forKey: importedFontsKey) ?? []
        // 注册已导入的字体
        FontImporter.registerAll(names: self.importedFonts)
    }

    func save() {
        UserDefaults.standard.set(fontSize.rawValue, forKey: fontSizeKey)
        UserDefaults.standard.set(density.rawValue, forKey: densityKey)
        UserDefaults.standard.set(customFontName ?? "", forKey: customFontKey)
        UserDefaults.standard.set(importedFonts, forKey: importedFontsKey)
    }

    func useSystemFont() {
        customFontName = nil
    }

    func useFont(_ psName: String) {
        customFontName = psName
    }

    func deleteFont(_ psName: String) {
        FontImporter.deleteFont(named: psName)
        importedFonts.removeAll { $0 == psName }
        if customFontName == psName {
            customFontName = nil
        }
        // 刷新已导入列表
        importedFonts = FontImporter.listImportedFonts()
    }

    /// 导入字体，返回 (PostScript名称, 错误信息)
    func importFontDetailed(from url: URL) -> (String?, String?) {
        let (psName, error) = FontImporter.importFontDetailed(from: url)
        if let psName = psName {
            importedFonts = FontImporter.listImportedFonts()
            return (psName, nil)
        }
        return (nil, error)
    }

    @discardableResult
    func importFont(from url: URL) -> String? {
        let (name, _) = importFontDetailed(from: url)
        return name
    }

    var sizeCategory: ContentSizeCategory {
        switch fontSize {
        case .small: return .small
        case .standard: return .medium
        case .large: return .large
        case .extraLarge: return .extraExtraLarge
        }
    }

    /// 基础字号（对应字体大小设置）
    var baseFontSize: CGFloat {
        switch fontSize {
        case .small: return 14
        case .standard: return 17
        case .large: return 20
        case .extraLarge: return 24
        }
    }

    var defaultFont: Font {
        if let name = customFontName {
            // relativeTo 让自定义字体跟随系统动态字体缩放
            return .custom(name, size: baseFontSize, relativeTo: .body)
        }
        return .system(size: baseFontSize)
    }
}

// TTF 字体导入器
enum FontImporter {
    static func fontsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Fonts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func importFont(from url: URL) -> String? {
        let (name, _) = importFontDetailed(from: url)
        return name
    }

    /// 返回 (PostScript名称, 错误信息)
    static func importFontDetailed(from url: URL) -> (String?, String?) {
        let fileName = url.lastPathComponent
        guard isFontFile(url) else {
            return (nil, "不支持的文件格式: \(url.pathExtension)")
        }
        let dest = fontsDirectory().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: dest)
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.copyItem(at: url, to: dest)
        } catch let e {
            return (nil, "复制文件失败: \(e.localizedDescription)")
        }
        guard let name = registerFont(at: dest) else {
            try? FileManager.default.removeItem(at: dest)
            return (nil, "字体注册失败，文件可能已损坏")
        }
        return (name, nil)
    }

    static func registerFont(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let cgFont = CGFont(provider) else { return nil }
        var error: Unmanaged<CFError>?
        guard CTFontManagerRegisterGraphicsFont(cgFont, &error) else { return nil }
        return cgFont.postScriptName as String?
    }

    /// 支持的字体格式
    static let supportedExtensions = ["ttf", "otf", "ttc", "otc"]

    static func isFontFile(_ url: URL) -> Bool {
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func registerAll(names: [String]) {
        let dir = fontsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files where isFontFile(file) {
            _ = registerFont(at: file)
        }
    }

    static func deleteFont(named postScriptName: String) {
        // 找到并删除字体文件，取消注册
        let dir = fontsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files where isFontFile(file) {
            if let data = try? Data(contentsOf: file),
               let provider = CGDataProvider(data: data as CFData),
               let cgFont = CGFont(provider),
               (cgFont.postScriptName as String?) == postScriptName {
                CTFontManagerUnregisterGraphicsFont(cgFont, nil)
                try? FileManager.default.removeItem(at: file)
                break
            }
        }
    }

    static func listImportedFonts() -> [String] {
        var names: [String] = []
        let dir = fontsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        for file in files where isFontFile(file) {
            // ttc/otc 可能包含多个字体，尝试读取第一个
            if let data = try? Data(contentsOf: file),
               let provider = CGDataProvider(data: data as CFData),
               let cgFont = CGFont(provider),
               let name = cgFont.postScriptName as String? {
                names.append(name)
            }
        }
        return names.sorted()
    }
}
