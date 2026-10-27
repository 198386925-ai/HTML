import UIKit
import WebKit

// MARK: - Weak script-message handler
//
// WKUserContentController retains its message handlers, so the handler
// must not retain the webview (or its owner) strongly, or the pair leaks
// for the life of the app. This wrapper holds only a weak reference.
private final class WeakHeightHandler: NSObject, WKScriptMessageHandler {
    // Set after the owning PreviewWebView finishes init, so the handler
    // never holds a strong reference and never needs `self` early.
    weak var owner: PreviewWebView?

    override init() {
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == PreviewWebView.heightMessageName,
              let body = message.body as? [String: Any],
              let height = body["height"] as? Double else { return }
        owner?.reportMeasuredHeight(CGFloat(height))
    }
}

// MARK: - PreviewWebView
//
// One WKWebView that renders the user's uploaded HTML in ONE colour
// scheme (light or dark). Two instances share the same original HTML;
// each injects its own colour scheme and, when present, the imported font.
//
// Height rule (the point of this class): the height is the real content
// extent, NOT body.scrollHeight and NOT the viewport height. A page whose
// body is min-height:100vh would otherwise always measure one full screen
// tall and leave a large blank area under a small card. See
// `measurementScript` for how wrapper shells are excluded.
final class PreviewWebView: UIView {

    static let heightMessageName = "htmlPreviewHeight"

    enum Scheme {
        case light
        case dark

        var cssValue: String {
            switch self {
            case .light: return "light"
            case .dark: return "dark"
            }
        }

        var interfaceStyle: UIUserInterfaceStyle {
            switch self {
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    /// Called on the main thread whenever a new content height is measured.
    /// Build 8: this height is the content's OWN measured size and is
    /// never overwritten by the capsule/card height. The card-height
    /// control changes only the capsule's height (GlassCapsuleView);
    /// this heightConstraint stays at the measured extent, so content
    /// never auto-fits, auto-resizes or stretches to match the capsule.
    /// Only the manual 内容缩放 control (applyTransform scale) scales
    /// content, and only when the user explicitly uses it.
    var onHeightMeasured: ((CGFloat) -> Void)?

    private let scheme: Scheme
    private let webView: WKWebView
    private let heightHandler: WeakHeightHandler
    private var heightConstraint: NSLayoutConstraint!

    private var originalHTML: String?
    private var importedFont: ImportedFont?

    /// Last content extent reported by the page script (untransformed).
    var measuredHeight: CGFloat = 0

    // MARK: Build 4 adjustments (applied to the WKWebView view itself,
    // so height measurement inside the page is unaffected)

    /// Last transform applied, re-applied after every load so a
    /// reload (new file, font import, permission-granted re-render)
    /// can never leave part of the content untransformed.
    private var lastTransform = CGAffineTransform.identity

    /// Offset (points) + scale for the WHOLE web content.
    /// The transform is set on the WKWebView view itself, not on any
    /// inner element, so avatar, phone number, subtitle, icons, text
    /// and images all move, scale and clip together — nothing inside
    /// the card stays static while the card is adjusted. Scale is
    /// around the view centre; the capsule clips overflow, so the
    /// capsule itself never moves or resizes for offset/scale changes.
    func applyTransform(offsetX: CGFloat, offsetY: CGFloat, scale: CGFloat) {
        var t = CGAffineTransform(scaleX: scale, y: scale)
        t.tx = offsetX
        t.ty = offsetY
        lastTransform = t
        webView.transform = t
    }

    /// Interactive toggle: OFF disables interaction on the webview, so
    /// taps fall through to the scroll view behind it.
    func setInteractive(_ enabled: Bool) {
        webView.isUserInteractionEnabled = enabled
    }

    init(scheme: Scheme) {
        self.scheme = scheme

        let configuration = WKWebViewConfiguration()
        // Build 7 (location): nothing here blocks the page's location
        // lookup. JavaScript stays enabled and no content rule blocks
        // geolocation; whether the page's own geolocation call succeeds
        // depends on the app's location authorization (requested by
        // MainViewController), not on this configuration.
        // No JavaScript bridge is needed except the height reporter, which
        // is added to this webview's own configuration only. The handler
        // is created without an owner first (it holds only a weak one),
        // then pointed at this instance after super.init.
        let handler = WeakHeightHandler()
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.heightHandler = handler
        super.init(frame: .zero)

        handler.owner = self
        configuration.userContentController.add(handler, name: Self.heightMessageName)

        // The outer UIScrollView scrolls. The webview itself must not
        // scroll internally, or its internal scroll area would add blank
        // space and fight the height-follows-content layout.
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        // Background removal (user's first step: "remove the background,
        // that is the liquid glass effect"): the webview itself must not
        // paint a solid background over the system glass behind it.
        // Only the background is made transparent here — text, icons,
        // layout and font of the uploaded page are untouched.
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        backgroundColor = .clear
        webView.navigationDelegate = self

        // Forcing the trait collection is the second half of the
        // prefers-color-scheme story: pages that use
        // @media (prefers-color-scheme: dark) follow this, while pages
        // with their own light/dark classes still paint as written.
        // The injected `color-scheme` CSS (below) covers the other half.
        // NOTE: this is set on the container view in GlassCapsuleView as
        // well, because WKWebView reads its view hierarchy's traits.
        overrideUserInterfaceStyle = scheme.interfaceStyle

        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        heightConstraint = webView.heightAnchor.constraint(equalToConstant: 120)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightConstraint,
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used; this app builds its UI in code.")
    }

    // MARK: Loading

    /// Renders `html` in this webview's colour scheme, with `font` applied
    /// to both previews when present. Call again after a font is imported
    /// or removed to re-render with the same HTML.
    func load(html: String, font: ImportedFont?) {
        originalHTML = html
        importedFont = font
        // Build 8 location fix: baseURL https://localhost/ instead of
        // nil. loadHTMLString with baseURL nil gives the page an
        // opaque about:blank origin, in which WKWebView geolocation is
        // blocked even when the app itself is authorized — the exact
        // "permission granted but card still shows no location" chain.
        // localhost is a secure context, so the page's geolocation
        // call can use the app's authorization. Font is injected
        // inline as a data URL, so no relative resource changes.
        webView.loadHTMLString(processedHTML(from: html, font: font), baseURL: URL(string: "https://localhost/"))
        // Re-apply the whole-content transform so the reloaded card
        // (avatar, text, icons included) keeps following the card's
        // current height/offset/scale adjustments.
        webView.transform = lastTransform
    }

    /// Clears the preview back to an empty, zero-content state.
    func clear() {
        originalHTML = nil
        importedFont = nil
        webView.loadHTMLString("", baseURL: nil)
        reportMeasuredHeight(0)
    }

    func reportMeasuredHeight(_ height: CGFloat) {
        // Clamp only the degenerate cases: a failed measurement (0) and
        // absurd values from a runaway script. Real card content is
        // typically well under 3000pt; a genuinely long page still grows
        // because the outer scroll view scrolls.
        let clamped = height <= 0 ? CGFloat(0) : min(height, 4000)
        measuredHeight = clamped
        heightConstraint.constant = clamped
        onHeightMeasured?(clamped)
    }

    // MARK: HTML processing (injection only, no body restyling)

    private func processedHTML(from html: String, font: ImportedFont?) -> String {
        var injection = ""
        // Colour scheme for this pane. This does not repaint the page:
        // it tells the browser which scheme the page's own light/dark
        // rules (media queries, color-scheme-aware controls) should use.
        injection += "<meta name=\"color-scheme\" content=\"\(scheme.cssValue)\">"
        injection += "<style data-preview-scheme=\"1\">:root { color-scheme: \(scheme.cssValue); } html { color-scheme: \(scheme.cssValue); }</style>"
        // Background removal, html/body only: make the page's root
        // backgrounds transparent so the native system glass behind
        // this webview becomes the card's background. Inner elements
        // (text, icons, card divs) keep their own styles — only the
        // html/body background is forced transparent, with !important
        // so the page's own body background rule cannot cover the glass.
        injection += "<style data-preview-glass=\"1\">html, body { background: transparent !important; background-color: transparent !important; }</style>"
        if let font = font {
            injection += font.fontFaceStyleBlock()
        }
        // A mobile viewport helps card pages lay out at phone width.
        // Only add one if the page did not already declare one.
        if !html.lowercased().contains("name=\"viewport\"") && !html.lowercased().contains("name='viewport'") {
            injection += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">"
        }
        injection += "<script>\(measurementScript)</script>"

        if let headClose = html.range(of: "</head>", options: .caseInsensitive) {
            var result = html
            result.insert(contentsOf: injection, at: headClose.lowerBound)
            return result
        }
        if let bodyOpen = html.range(of: "<body", options: .caseInsensitive) {
            var result = html
            result.insert(contentsOf: injection, at: bodyOpen.lowerBound)
            return result
        }
        return injection + html
    }

    // MARK: Content-extent measurement
    //
    // Rules, in order:
    // 1. Never use body.scrollHeight / documentElement.scrollHeight as
    //    the height: a 100vh shell makes those equal to the viewport.
    // 2. Count only "meaningful" elements: visible leaves, images, and
    //    elements that actually paint (a non-transparent background, a
    //    border, or a shadow). A full-height wrapper div that only holds
    //    the card paints nothing itself, so it does not count.
    // 3. The extent is the lowest bottom edge of those elements, measured
    //    from the top of <body>. Trailing blank space inside a wrapper
    //    therefore does not count, and the capsule shrinks to the card.
    private var measurementScript: String {
        """
        (function () {
          function measure() {
            try {
              var body = document.body;
              if (!body) { return 0; }
              var bodyTop = body.getBoundingClientRect().top + window.scrollY;
              var maxBottom = 0;
              var nodes = body.querySelectorAll('*');
              for (var i = 0; i < nodes.length; i++) {
                var el = nodes[i];
                var tag = el.tagName;
                if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'LINK' || tag === 'META' || tag === 'HEAD') { continue; }
                var style = window.getComputedStyle(el);
                if (style.display === 'none' || style.visibility === 'hidden' || style.visibility === 'collapse') { continue; }
                if (parseFloat(style.opacity || '1') === 0) { continue; }
                var rect = el.getBoundingClientRect();
                if (rect.width <= 0 || rect.height <= 0) { continue; }
                // Leaf elements (no element children) always count:
                // text runs, images and icons live here.
                var isLeaf = el.children.length === 0;
                // A container counts only if it paints something itself.
                var bg = style.backgroundColor;
                var paints = (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent')
                  || parseFloat(style.borderTopWidth || '0') > 0
                  || parseFloat(style.borderBottomWidth || '0') > 0
                  || (style.boxShadow && style.boxShadow !== 'none');
                if (!isLeaf && !paints) { continue; }
                var bottom = rect.bottom + window.scrollY - bodyTop;
                if (bottom > maxBottom) { maxBottom = bottom; }
              }
              if (maxBottom <= 0) {
                // Fallback only when nothing meaningful was found.
                maxBottom = Math.max(body.scrollHeight, document.documentElement.scrollHeight);
              }
              return Math.ceil(maxBottom);
            } catch (e) { return 0; }
          }
          function report() {
            try {
              window.webkit.messageHandlers.htmlPreviewHeight.postMessage({ height: measure() });
            } catch (e) {}
          }
          // Re-measure after fonts and late layout settle. The native
          // side only applies a change of >= 1pt, so repeats are cheap.
          window.addEventListener('load', function () {
            report();
            setTimeout(report, 120);
            setTimeout(report, 450);
            setTimeout(report, 1000);
          });
          window.addEventListener('resize', report);
          try {
            var observer = new MutationObserver(function () { report(); });
            if (document.body) {
              observer.observe(document.body, { childList: true, subtree: true, attributes: true });
            }
          } catch (e) {}
          // First attempt as soon as this script runs (head injection).
          document.addEventListener('DOMContentLoaded', report);
        })();
        """
    }
}

// MARK: - WKNavigationDelegate

extension PreviewWebView: WKNavigationDelegate {
    // No work is needed here: the measurement script is injected into
    // the page itself and reports on load, on resize, on DOM mutation,
    // and again at 120 / 450 / 1000 ms after load. Posting a synthetic
    // height from here would only overwrite a real measurement with 0.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}
}
