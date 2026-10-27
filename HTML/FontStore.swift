import Foundation
import CoreText
import UniformTypeIdentifiers

// Holds one user-imported font file and builds the @font-face CSS that is
// injected into BOTH webviews. The uploaded HTML body's own opacity /
// transparency is never touched: this file only adds a font-family rule.
struct ImportedFont {
    let fileName: String
    let data: Data

    /// File extension, lowercased, without the leading dot.
    var fileExtension: String {
        (fileName as NSString).pathExtension.lowercased()
    }

    /// MIME type for the data: URL used in @font-face.
    var mimeType: String {
        switch fileExtension {
        case "otf": return "font/otf"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        default: return "font/ttf"
        }
    }

    /// CSS format() hint for the @font-face rule.
    var cssFormat: String {
        switch fileExtension {
        case "otf": return "opentype"
        case "woff": return "woff"
        case "woff2": return "woff2"
        default: return "truetype"
        }
    }

    /// True for extensions this app accepts. woff/woff2 are valid here even
    /// though CoreText cannot register them: WebKit's @font-face handles
    /// them from the data URL below, so registration is best-effort only.
    static func isSupported(fileName: String) -> Bool {
        ["ttf", "otf", "woff", "woff2"].contains((fileName as NSString).pathExtension.lowercased())
    }

    /// Best-effort system registration (ttf/otf only). Failure is ignored:
    /// the webviews do not depend on it, they use the data URL below.
    func registerIfPossible() {
        guard fileExtension == "ttf" || fileExtension == "otf" else { return }
        guard let provider = CGDataProvider(data: data as CFData),
              let font = CGFont(provider) else { return }
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterGraphicsFont(font, &error)
    }

    /// One <style> block, injected into each webview. The data URL keeps the
    /// font inside the preview (no local-file URL, no baseURL dependency).
    /// `!important` is intentional: the user imported this font precisely
    /// so both previews use it instead of the page's own font.
    func fontFaceStyleBlock() -> String {
        let base64 = data.base64EncodedString()
        return """
        <style data-preview-font="1">
        @font-face {
          font-family: 'PreviewImportedFont';
          src: url(data:\(mimeType);base64,\(base64)) format('\(cssFormat)');
          font-display: swap;
        }
        * { font-family: 'PreviewImportedFont', sans-serif !important; }
        </style>
        """
    }
}

// The UTType list shown by the font picker. UTType.font covers ttf/otf;
// woff/woff2 are added by extension when the platform knows them.
enum FontPickerTypes {
    static var allowed: [UTType] {
        var types: [UTType] = [.font]
        for ext in ["woff", "woff2"] {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
        return types
    }
}
