import SwiftUI
import CoreText

/// 全局显示设置：字体大小、布局疏密、自定义TTF字体
class AppDisplaySettings: ObservableObject {
    @Published var fontSize: DeviceFontSize = .standard
    @Published var density: DeviceDensity = .standard
    /// 当前使用的自定义字体 PostScript 名，nil = 系统字体
    @Published var customFontName: String? = nil
    /// 已导入的字体 PostScript 名列表
    @Published var importedFonts: [String] = []

    private static let kFontSize = "appFontSize"
    private static let kDensity = "appDensity"
    private static let kCustomFont = "appCustomFont"
    private static let kImported = "appImportedFonts"

    init() {
        let d = UserDefaults.standard
        if let v = d.string(forKey: Self.kFontSize),
           let fs = DeviceFontSize(rawValue: v) {
            fontSize = fs
        }
        if let v = d.string(forKey: Self.kDensity),
           let dn = DeviceDensity(rawValue: v) {
            density = dn
        }
        customFontName = d.string(forKey: Self.kCustomFont)
        importedFonts = d.stringArray(forKey: Self.kImported) ?? []
        // 启动时注册所有已导入字体
        FontImporter.registerAll()
        // 清理已删除的字体选择
        if let sel = customFontName, !importedFonts.contains(sel) {
            customFontName = nil
        }
    }

    func save() {
        let d = UserDefaults.standard
        d.set(fontSize.rawValue, forKey: Self.kFontSize)
        d.set(density.rawValue, forKey: Self.kDensity)
        d.set(customFontName, forKey: Self.kCustomFont)
        d.set(importedFonts, forKey: Self.kImported)
    }

    /// 字号映射
    var sizeCategory: ContentSizeCategory {
        switch fontSize {
        case .small: return .small
        case .standard: return .medium
        case .large: return .large
        case .extraLarge: return .extraExtraLarge
        }
    }

    /// 全局默认字体（自定义TTF或系统）
    var defaultFont: Font? {
        guard let name = customFontName else { return nil }
        return Font.custom(name, size: 17)
    }

    /// 导入 TTF，返回 PostScript 名
    func importFont(from url: URL) -> String? {
        guard let psName = FontImporter.importTTF(from: url) else { return nil }
        if !importedFonts.contains(psName) {
            importedFonts.append(psName)
        }
        customFontName = psName
        save()
        return psName
    }

    func deleteFont(_ psName: String) {
        FontImporter.delete(psName: psName)
        importedFonts.removeAll(where: { $0 == psName })
        if customFontName == psName { customFontName = nil }
        save()
    }

    func useSystemFont() {
        customFontName = nil
        save()
    }

    func useFont(_ psName: String) {
        customFontName = psName
        save()
    }
}

/// TTF 字体导入/注册
enum FontImporter {
    static var fontsDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Fonts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 从外部 URL 导入 TTF，返回 PostScript 名
    static func importTTF(from url: URL) -> String? {
        let dest = fontsDir.appendingPathComponent(url.lastPathComponent)
        // 先移除同名
        try? FileManager.default.removeItem(at: dest)
        // 需要先获取访问权限（fileImporter 给的 URL）
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.copyItem(at: url, to: dest)
        } catch {
            return nil
        }
        return register(at: dest)
    }

    /// 注册单个字体文件，返回 PostScript 名
    @discardableResult
    static func register(at url: URL) -> String? {
        var error: Unmanaged<CFError>?
        guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else {
            // 可能已注册，尝试读取名字
            return postScriptName(at: url)
        }
        return postScriptName(at: url)
    }

    static func postScriptName(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let cgFont = CGFont(provider) else { return nil }
        return cgFont.postScriptName as String?
    }

    /// 启动时注册所有已导入字体
    static func registerAll() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: fontsDir, includingPropertiesForKeys: nil) else { return }
        for f in files where f.pathExtension.lowercased() == "ttf" {
            register(at: f)
        }
    }

    static func delete(psName: String) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: fontsDir, includingPropertiesForKeys: nil) else { return }
        for f in files {
            if postScriptName(at: f) == psName {
                try? FileManager.default.removeItem(at: f)
                var error: Unmanaged<CFError>?
                CTFontManagerUnregisterFontsForURL(f as CFURL, .process, &error)
            }
        }
    }
}
