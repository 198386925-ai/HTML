import UIKit

// MARK: - GlassCapsuleView (Build 3: solid colour, no glass)
//
// Build 3 supersedes the liquid-glass requirement for the capsules,
// per the user's device test of Build 2 ("改纯色啊"):
// Build 2 removed all backgrounds, so in system dark mode the whole
// page was black, the dark capsule was invisible except floating
// text/icons, and dark-grey top text on black was unreadable.
//
// This view is now a flat solid-colour capsule, full stop:
// * Light capsule: solid white background.
// * Dark capsule: solid black background.
// * No UIGlassEffect, no UIVisualEffectView, no transparency.
// * No gradient, no shadow, no highlight, no border drawn to
//   simulate glass — solid colour only, flat.
// * The only layer property set here is cornerRadius, as geometry
//   to clip the capsule (and the preview inside it) to a capsule
//   shape. Clipping to a shape is not drawing a material.
//
// The PreviewWebView inside stays transparent (html/body background
// forced transparent), so this solid capsule colour IS the visible
// card background, and the uploaded page's text/icons sit on top of
// it in their own colours. The class name is kept unchanged so
// MainViewController needs no changes for this file.
final class GlassCapsuleView: UIView {

    enum Kind {
        case light
        case dark
    }

    let preview: PreviewWebView

    private let kind: Kind

    init(kind: Kind) {
        self.kind = kind
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

        // Solid colour only, flat.
        switch kind {
        case .light:
            backgroundColor = .white
        case .dark:
            backgroundColor = .black
        }
        clipsToBounds = true

        addSubview(preview)
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.layer.cornerRadius = 0
        preview.clipsToBounds = true
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: topAnchor),
            preview.leadingAnchor.constraint(equalTo: leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: trailingAnchor),
            preview.bottomAnchor.constraint(equalTo: bottomAnchor),
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
        // This sets a clip radius only; it paints nothing extra.
        let radius = min(bounds.height / 2, 36)
        layer.cornerRadius = radius
        preview.layer.cornerRadius = radius
    }
}
