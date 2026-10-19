import SwiftUI
import UIKit
import ObjectiveC
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
        // if let cf = self.customFontName {
        FontHook.shared.setCustomFont(cf) 
        // }
    }

    func save() {
        UserDefaults.standard.set(fontSize.rawValue, forKey: fontSizeKey)
        UserDefaults.standard.set(density.rawValue, forKey: densityKey)
        UserDefaults.standard.set(customFontName ?? "", forKey: customFontKey)
        UserDefaults.standard.set(importedFonts, forKey: importedFontsKey)
    }

    func useSystemFont() {
        customFontName = nil
        FontHook.shared.setCustomFont(nil) 
    }

    func useFont(_ psName: String) {
        customFontName = psName
        FontHook.shared.setCustomFont(psName) 
    }

    func deleteFont(_ psName: String) {
        FontImporter.deleteFont(named: psName)
        importedFonts.removeAll { $0 == psName }
        if customFontName == psName {
            customFontName = nil
            FontHook.shared.setCustomFont(nil) 
        }
        // 刷新已导入列表
        importedFonts = FontImporter.listImportedFonts()
    }

    /// 导入字体，返回 (PostScript名称, 错误信息)
    func importFontDetailed(from url: URL) -> (String?, String?) {
        let (psName, error) = FontImporter.importFontDetailed(from: url)
        if let psName = psName {
            // 直接追加，不依赖重新扫描（大字体文件扫描可能失败）
            if !importedFonts.contains(psName) {
                importedFonts.append(psName)
            }
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
            return .custom(name, size: baseFontSize, relativeTo: .body)
        }
        return .system(size: baseFontSize)
    }
    private func cf(_ size: CGFloat, _ style: Font.TextStyle) -> Font {
        if let name = customFontName { return .custom(name, size: size) }
        return .system(style)
    }
    var fHeadline: Font { cf(17, .headline) }
    var fBody: Font { cf(17, .body) }
    var fCallout: Font { cf(16, .callout) }
    var fSubheadline: Font { cf(15, .subheadline) }
    var fFootnote: Font { cf(13, .footnote) }
    var fCaption: Font { cf(12, .caption) }
    var fCaption2: Font { cf(11, .caption2) }
    var fTitle: Font { cf(28, .title) }
    var fTitle2: Font { cf(22, .title2) }
    var fTitle3: Font { cf(20, .title3) }
    var fLargeTitle: Font { cf(34, .largeTitle) }

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

// MARK: - iOS 26 原生液态玻璃（低版本自动回退，绝不自绘）
extension View {
    /// 原生液态玻璃卡片：iOS 26+ 用系统 glassEffect；低版本用系统背景+圆角+阴影（均为原生修饰符）
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 24) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self
                .background(Color(.systemBackground))
                .cornerRadius(cornerRadius)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }

    /// 原生液态玻璃胶囊：iOS 26+ 用系统 glassEffect；低版本保持原样
    @ViewBuilder
    func nativeCapsuleGlass() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: Capsule())
        } else {
            self
        }
    }
}

/// App 内全局字体替换（原理同 FontHook 插件：Hook UIFont 方法）
/// 非越狱环境下仅对本 App 进程生效
class FontHook {
    static let shared = FontHook()
    private var customFontName: String?
    private var isHooked = false

    private init() {}

    /// 设置自定义字体（nil 则恢复系统字体）
    func setCustomFont(_ postScriptName: String?) {
        customFontName = postScriptName
        if postScriptName != nil {
            hookIfNeeded()
        }
    }

    var activeFontName: String? { customFontName }

    private func hookIfNeeded() {
        guard !isHooked else { return }
        isHooked = true

        // Hook UIFont.systemFont(ofSize:)
        swizzle(
            cls: UIFont.self,
            original: #selector(UIFont.systemFont(ofSize:)),
            swizzled: #selector(UIFont.fh_systemFont(ofSize:))
        )
        // Hook UIFont.boldSystemFont(ofSize:)
        swizzle(
            cls: UIFont.self,
            original: #selector(UIFont.boldSystemFont(ofSize:)),
            swizzled: #selector(UIFont.fh_boldSystemFont(ofSize:))
        )
        // Hook UIFont.systemFont(ofSize:weight:)
        swizzle(
            cls: UIFont.self,
            original: #selector(UIFont.systemFont(ofSize:weight:)),
            swizzled: #selector(UIFont.fh_systemFont(ofSize:weight:))
        )
        // Hook UIFont.italicSystemFont(ofSize:)
        swizzle(
            cls: UIFont.self,
            original: #selector(UIFont.italicSystemFont(ofSize:)),
            swizzled: #selector(UIFont.fh_italicSystemFont(ofSize:))
        )
        // Hook UIFont.preferredFont(forTextStyle:) - SwiftUI .font(.headline) 等走这里
        swizzle(
            cls: UIFont.self,
            original: #selector(UIFont.preferredFont(forTextStyle:)),
            swizzled: #selector(UIFont.fh_preferredFont(forTextStyle:))
        )
    }

    private func swizzle(cls: AnyClass, original: Selector, swizzled: Selector) {
        guard let origMethod = class_getClassMethod(cls, original),
              let swizMethod = class_getClassMethod(cls, swizzled) else { return }
        method_exchangeImplementations(origMethod, swizMethod)
    }

    /// 根据原始字体返回替换后的字体
    func replacedFont(for original: UIFont) -> UIFont {
        guard let name = customFontName else { return original }
        // 尝试用自定义字体同名、同大小创建
        if let custom = UIFont(name: name, size: original.pointSize) {
            return custom
        }
        return original
    }
}

// MARK: - UIFont 替换实现
extension UIFont {
    @objc dynamic class func fh_systemFont(ofSize size: CGFloat) -> UIFont {
        // 调用原始实现（已交换，实际调用的是原始 systemFont）
        let original = fh_systemFont(ofSize: size)
        return FontHook.shared.replacedFont(for: original)
    }

    @objc dynamic class func fh_boldSystemFont(ofSize size: CGFloat) -> UIFont {
        let original = fh_boldSystemFont(ofSize: size)
        return FontHook.shared.replacedFont(for: original)
    }

    @objc dynamic class func fh_systemFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let original = fh_systemFont(ofSize: size, weight: weight)
        return FontHook.shared.replacedFont(for: original)
    }

    @objc dynamic class func fh_italicSystemFont(ofSize size: CGFloat) -> UIFont {
        let original = fh_italicSystemFont(ofSize: size)
        return FontHook.shared.replacedFont(for: original)
    }
    
    @objc dynamic class func fh_preferredFont(forTextStyle style: UIFont.TextStyle) -> UIFont {
        let original = fh_preferredFont(forTextStyle: style)
        guard let customName = FontHook.shared.activeFontName else { return original }
        let size = original.pointSize
        if let custom = UIFont(name: customName, size: size) {
            return custom
        }
        return original
    }
}

