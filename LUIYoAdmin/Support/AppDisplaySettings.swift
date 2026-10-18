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

    var sizeCategory: ContentSizeCategory {
        switch fontSize {
        case .small: return .small
        case .standard: return .medium
        case .large: return .large
        case .extraLarge: return .extraExtraLarge
        }
    }

    var defaultFont: Font {
        if let name = customFontName {
            return .custom(name, size: 17)
        }
        return .system(size: 17)
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
        let dest = fontsDirectory().appendingPathComponent(url.lastPathComponent)
        // 如果已存在，先删除
        try? FileManager.default.removeItem(at: dest)
        do {
            // 需要先获取安全访问权限（fileImporter 给的是 security-scoped URL）
            guard url.startAccessingSecurityScopedResource() else { return nil }
            defer { url.stopAccessingSecurityScopedResource() }
            try FileManager.default.copyItem(at: url, to: dest)
        } catch {
            return nil
        }
        // 注册字体
        guard let name = registerFont(at: dest) else { return nil }
        return name
    }

    static func registerFont(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let cgFont = CGFont(provider) else { return nil }
        var error: Unmanaged<CFError>?
        guard CTFontManagerRegisterGraphicsFont(cgFont, &error) else { return nil }
        return cgFont.postScriptName as String?
    }

    static func registerAll(names: [String]) {
        // names 是 PostScript 名称，需要找到对应的文件
        // 简化：遍历 Fonts 目录，注册所有 ttf
        let dir = fontsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension.lowercased() == "ttf" {
            _ = registerFont(at: file)
        }
    }

    static func deleteFont(named postScriptName: String) {
        // 找到并删除字体文件，取消注册
        let dir = fontsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension.lowercased() == "ttf" {
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
        for file in files where file.pathExtension.lowercased() == "ttf" {
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
