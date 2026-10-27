import UIKit

// MARK: - GlassCapsuleView
//
// A native iOS 26 liquid-glass capsule that tightly wraps one
// PreviewWebView. HARD RULE, enforced here:
//
// * The glass is UIGlassEffect, rendered by the system through a
//   UIVisualEffectView. Nothing in this file draws glass.
// * No gradient layer, no borders, no shadows, no hand-drawn
//   highlight, no background
//   fill painted to look like glass. The capsule's own backgroundColor
//   is .clear; the system material is the only glass surface.
// * The only layer property set here is cornerRadius, and only as
//   geometry: it clips the system effect view to a capsule shape.
//   Clipping a system effect to a shape is not drawing the effect.
// * The webview sits inside the effect view's contentView, inset by
//   3pt on every side. That 3pt rim is the visible system glass;
//   the webview itself is not blurred, tinted, or made transparent
//   by this container. The uploaded page keeps its own background
//   and opacity exactly as written.
//
// Light vs dark: both capsules use UIGlassEffect(style: .regular).
// The tintColor below is a UIGlassEffect property, not a custom
// fill: .white tint for the light capsule, .black tint for the dark
// capsule, so the system glass adapts in the same direction as the
// preview inside it. isInteractive is false: this is a content
// preview, not a control, and an interactive tap expansion must not
// change the capsule's measured height.
final class GlassCapsuleView: UIView {

    enum Kind {
        case light
        case dark
    }

    let preview: PreviewWebView

    private let effectView: UIVisualEffectView
    private let kind: Kind

    init(kind: Kind) {
        self.kind = kind

        let glass = UIGlassEffect(style: .regular)
        glass.isInteractive = false
        switch kind {
        case .light:
            glass.tintColor = .white
        case .dark:
            glass.tintColor = .black
        }
        self.effectView = UIVisualEffectView(effect: glass)
        switch kind {
        case .light:
            self.preview = PreviewWebView(scheme: .light)
        case .dark:
            self.preview = PreviewWebView(scheme: .dark)
        }
        super.init(frame: .zero)

        // The capsule's own trait collection drives the webview's
        // prefers-color-scheme media queries (see PreviewWebView).
        switch kind {
        case .light:
            overrideUserInterfaceStyle = .light
        case .dark:
            overrideUserInterfaceStyle = .dark
        }

        // Geometry only: no fill, no border, no shadow on this view.
        backgroundColor = .clear
        effectView.backgroundColor = .clear
        effectView.clipsToBounds = true

        addSubview(effectView)
        effectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // The webview lives in the effect view's contentView, so the
        // system glass renders behind it and only the 3pt rim shows.
        // The webview's own corners are clipped to the same capsule
        // shape, again geometry only, no material drawing.
        effectView.contentView.addSubview(preview)
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.layer.cornerRadius = 0
        preview.clipsToBounds = true
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: effectView.contentView.topAnchor, constant: 3),
            preview.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: 3),
            preview.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: 3),
            preview.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor, constant: -3),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used; this app builds its UI in code.")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Capsule geometry: half the height, capped at 36pt so a tall
        // page preview does not become a full semicircle at each end.
        // This sets a clip radius only; it paints nothing.
        let radius = min(bounds.height / 2, 36)
        effectView.layer.cornerRadius = radius
        preview.layer.cornerRadius = max(radius - 3, 0)
    }
}
