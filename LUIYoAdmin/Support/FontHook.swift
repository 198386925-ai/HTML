import UIKit
import ObjectiveC

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
}
