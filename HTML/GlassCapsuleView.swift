import UIKit

// MARK: - GlassCapsuleView (Build 8: native liquid glass capsule)
//
// Build 8 correction, per the user's follow-up ("在这两个位置加一个
// 原生液态玻璃的胶囊卡片，不要自绘的"): the two preview positions —
// light on top, dark below — are each a NATIVE liquid-glass capsule
// card, not a solid colour and not a fully transparent nothing.
// This supersedes the first Build 8 draft's fully-transparent capsule.
//
// Native only, no self-drawing:
// * UIKit iOS 26 UIGlassEffect(style: .regular) in a UIVisualEffectView.
// * UIGlassEffect.isInteractive = false (the glass itself does not
//   react/expand on tap; the web content's own interaction toggle
//   is separate, in PreviewWebView).
// * Tint: light capsule .white, dark capsule .black — a UIGlassEffect
//   property, not a drawn fill.
// * No self-drawn gradient, border, shadow or highlight anywhere.
// * The only layer property set here is cornerRadius, as geometry
//   to clip the capsule (and the preview inside it) to a capsule
//   shape. Clipping to a shape is not drawing a material.
//
// How it is layered:
// * The glass effect view fills the whole capsule (its size is the
//   card height set by the 卡片高度 control).
// * The preview (web content) sits in the effect view's contentView,
//   on top of the glass — so the glass is behind the content, the
//   content is not blurred by the glass, and the glass shows around
//   the content wherever the content does not paint.
//
// Content size does NOT follow card size (unchanged Build 8 rule):
// * The preview's own height is always its measured content height
//   (see PreviewWebView) and is never set to the capsule height,
//   so content never auto-fits, auto-resizes or stretches to match
//   the capsule, and content and capsule stay visibly different
//   sizes — the glass capsule remains visible around the content
//   and nothing is missing because the content was forced to fill it.
// * The preview is TOP-aligned inside the glass contentView: a
//   taller capsule leaves glass visible below the original-size
//   content, and a shorter capsule clips the BOTTOM of the content,
//   never the avatar / phone number at the top (the old
//   bottom-alignment clipped the top instead).
// * Horizontal/vertical offset still moves the whole content
//   (position follows) and the manual 内容缩放 control still scales
//   it, but only when the user explicitly uses it; height changes
//   alone never scale or resize content.
//
// Background colour removal, clarified by the correction:
// * "去掉背景颜色" means removing the old solid pure white / pure
//   black capsule backgrounds (Build 3/5) and replacing them with
//   native glass — not replacing them with nothing. There is no
//   solid white/black background in this file at any value.
//
// Build 9 correction (user: "液态玻璃不是背景透明度啊，背景透明度
// 调的是卡片的透明度"): glass and card-background transparency are
// SEPARATE. The glass below is ALWAYS present at full tint, whatever
// the background-transparency value is. That control now adjusts
// only the card background layer inside PreviewWebView (see
// setCardBackgroundAlpha), never the glass, never the content.
// The class name is kept unchanged so MainViewController needs no
// changes for this file's API (preview, setCapsuleHeight,
// setCardBackgroundAlpha).
final class GlassCapsuleView: UIView {

    enum Kind {
        case light
        case dark
    }

    let preview: PreviewWebView

    private let kind: Kind
    private let glassView: UIVisualEffectView
    private var capsuleHeightConstraint: NSLayoutConstraint?

    // Build 9: the glass effect is created ONCE at full tint and
    // never changed afterwards. There is deliberately no tint-alpha
    // parameter anywhere: background transparency must never turn
    // the glass off, fade it, or change its tint.
    // NOTE: do NOT read a computed self property (e.g. a baseTint
    // helper) in init before super.init — Swift rejects 'self' used
    // before super.init (that was the Build 9 first-run failure).
    // The tint below therefore uses the already-assigned `kind`
    // stored property directly, as the original code did.

    /// Capsule height, independent of the web content height.
    /// Changing this height never resizes, scales or stretches the
    /// content (see the header comment): it only changes how much
    /// native glass shows around the original-size content.
    func setCapsuleHeight(_ height: CGFloat) {
        let h = max(height, 0)
        if let c = capsuleHeightConstraint {
            c.constant = h
        } else {
            let c = heightAnchor.constraint(equalToConstant: h)
            c.isActive = true
            capsuleHeightConstraint = c
        }
    }

    /// Background transparency control (title line, step 5).
    /// Build 9: this adjusts ONLY the card background layer inside
    /// the preview (PreviewWebView.setCardBackgroundAlpha). The
    /// glass effect view is never touched here — not its effect,
    /// not its tint, not its alpha — so the native glass stays
    /// fully present at every transparency value, and the content
    /// (text, avatar, icons) is never faded either. 0 = card
    /// background fully transparent (glass behind shows through
    /// where the card drew nothing); 100 = card background fully
    /// solid (scheme colour behind the content).
    func setCardBackgroundAlpha(_ alpha: CGFloat) {
        preview.setCardBackgroundAlpha(alpha)
    }

    init(kind: Kind) {
        self.kind = kind
        switch kind {
        case .light:
            self.preview = PreviewWebView(scheme: .light)
        case .dark:
            self.preview = PreviewWebView(scheme: .dark)
        }
        // Native glass, created once with full tint and never
        // changed afterwards (Build 9: background transparency does
        // not touch the glass at all).
        let initialEffect = UIGlassEffect(style: .regular)
        initialEffect.isInteractive = false
        initialEffect.tintColor = kind == .light ? .white : .black
        self.glassView = UIVisualEffectView(effect: initialEffect)
        super.init(frame: .zero)

        // The capsule's own trait collection drives the webview's
        // prefers-color-scheme media queries (see PreviewWebView).
        switch kind {
        case .light:
            overrideUserInterfaceStyle = .light
        case .dark:
            overrideUserInterfaceStyle = .dark
        }

        // No solid background on the capsule itself: the glass is
        // the card's surface.
        backgroundColor = .clear
        glassView.backgroundColor = .clear
        glassView.clipsToBounds = true
        clipsToBounds = true

        addSubview(glassView)
        glassView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Content lives in the glass effect view's contentView, on top
        // of the glass, top-aligned, at its own measured height.
        // Pinning its bottom as well would force it to stretch to the
        // capsule height and break content-size independence.
        glassView.contentView.addSubview(preview)
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.layer.cornerRadius = 0
        preview.clipsToBounds = true
        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor),
            preview.topAnchor.constraint(equalTo: glassView.contentView.topAnchor),
        ])
        // Definite initial height so the capsule is not ambiguous
        // before the first measured height arrives.
        setCapsuleHeight(120)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used; this app builds its UI in code.")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Capsule geometry: half the height, capped at 36pt so a tall
        // page preview does not become a full semicircle at each end.
        // This sets a clip radius only; it paints nothing extra.
        let radius = min(bounds.height / 2, 36)
        layer.cornerRadius = radius
        glassView.layer.cornerRadius = radius
        preview.layer.cornerRadius = radius
    }
}
