import UIKit
import UniformTypeIdentifiers

// MARK: - MainViewController
//
// UIKit-only screen. Layout, top bar, buttons, font tag and the two
// glass capsules are all UIKit (UIView / UILabel / UIButton /
// UIStackView / UIScrollView). There is no declarative UI framework view, no
// hosting controller and no declarative UI framework import in this file or anywhere
// in the app.
//
// Confirmed scope only, nothing extra:
// * Pick a .html file, preview it whole (light on top, dark below).
// * Two separate glass capsules with a gap between them, no overlap,
//   no fade mask pressing on card content.
// * Preview height follows the card content (see PreviewWebView).
// * Import a font (.ttf/.otf/.woff/.woff2) for both previews, with a
//   font tag that can be removed or replaced.
// * Top bar: file name, replace file, clear, import font, share.
//   There is no "new window" on iPhone; Share (UIActivityViewController)
//   is the trivial equivalent and is the only extra top-bar action.
final class MainViewController: UIViewController {

    // MARK: State (in memory only; nothing is persisted or uploaded)

    private var htmlText: String?
    private var htmlFileName: String?
    private var htmlFileURLForShare: URL?
    private var importedFont: ImportedFont?

    // MARK: Views

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let fileNameLabel = UILabel()
    private let fileSizeLabel = UILabel()

    private let replaceButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let importFontButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)

    private let fontTagView = UIView()
    private let fontTagContainer = UIView()
    private let fontTagLabel = UILabel()
    private let fontRemoveButton = UIButton(type: .system)

    private let emptyLabel = UILabel()
    private let lightCapsule = GlassCapsuleView(kind: .light)
    private let darkCapsule = GlassCapsuleView(kind: .dark)

    // The picker's purpose (HTML vs font) is remembered across the
    // delegate callback, because UIDocumentPickerViewController does
    // not carry a user-defined tag.
    private enum PickPurpose {
        case html
        case font
    }
    private var currentPickPurpose: PickPurpose = .html

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildLayout()
        updateForNoFile()
    }

    // MARK: Layout (all UIKit, all system colours, no drawn decoration)

    private func buildLayout() {
        titleLabel.text = "HTML"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        fileNameLabel.font = .preferredFont(forTextStyle: .headline)
        fileNameLabel.textColor = .label
        fileNameLabel.numberOfLines = 1
        fileNameLabel.lineBreakMode = .byTruncatingMiddle

        fileSizeLabel.font = .preferredFont(forTextStyle: .subheadline)
        fileSizeLabel.textColor = .secondaryLabel
        fileSizeLabel.numberOfLines = 1

        replaceButton.setTitle("更换文件", for: .normal)
        replaceButton.addTarget(self, action: #selector(replaceTapped), for: .touchUpInside)
        clearButton.setTitle("清除", for: .normal)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        importFontButton.setTitle("导入字体", for: .normal)
        importFontButton.addTarget(self, action: #selector(importFontTapped), for: .touchUpInside)
        shareButton.setTitle("分享", for: .normal)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)

        fontTagLabel.font = .preferredFont(forTextStyle: .subheadline)
        fontTagLabel.textColor = .label
        fontTagLabel.numberOfLines = 1
        fontTagLabel.lineBreakMode = .byTruncatingMiddle
        fontRemoveButton.setTitle("×", for: .normal)
        fontRemoveButton.titleLabel?.font = .preferredFont(forTextStyle: .title2)
        fontRemoveButton.addTarget(self, action: #selector(removeFontTapped), for: .touchUpInside)
        // The font tag is a plain system-colour pill container, not a
        // glass simulation: no gradient, no shadow, no highlight.
        fontTagView.backgroundColor = .secondarySystemBackground
        fontTagView.layer.cornerRadius = 16
        fontTagView.isHidden = true
        fontTagContainer.isHidden = true

        emptyLabel.text = "选一个 .html 文件，就会在下面整页预览：上面浅色，下面深色。"
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center

        // Top bar: title, file info, then the four actions.
        let buttonRow = UIStackView(arrangedSubviews: [replaceButton, clearButton, importFontButton, shareButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 16
        buttonRow.alignment = .leading

        let fontTagRow = UIStackView(arrangedSubviews: [fontTagLabel, fontRemoveButton])
        fontTagRow.axis = .horizontal
        fontTagRow.spacing = 8
        fontTagRow.alignment = .center
        fontTagView.addSubview(fontTagRow)
        fontTagRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fontTagRow.topAnchor.constraint(equalTo: fontTagView.topAnchor, constant: 6),
            fontTagRow.leadingAnchor.constraint(equalTo: fontTagView.leadingAnchor, constant: 12),
            fontTagRow.trailingAnchor.constraint(equalTo: fontTagView.trailingAnchor, constant: -8),
            fontTagRow.bottomAnchor.constraint(equalTo: fontTagView.bottomAnchor, constant: -6),
        ])

        // Previews: light capsule, then a gap, then the dark capsule.
        // They are separate views in a stack with spacing, never
        // overlapping and never masked into each other.
        stackView.axis = .vertical
        stackView.spacing = 18
        stackView.alignment = .fill
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(fileNameLabel)
        stackView.addArrangedSubview(fileSizeLabel)
        stackView.addArrangedSubview(buttonRow)
        // The tag pill must not stretch to full stack width: it lives in
        // a plain container and sizes to its own label + remove button.
        fontTagContainer.addSubview(fontTagView)
        fontTagView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fontTagView.topAnchor.constraint(equalTo: fontTagContainer.topAnchor),
            fontTagView.leadingAnchor.constraint(equalTo: fontTagContainer.leadingAnchor),
            fontTagView.trailingAnchor.constraint(lessThanOrEqualTo: fontTagContainer.trailingAnchor),
            fontTagView.bottomAnchor.constraint(equalTo: fontTagContainer.bottomAnchor),
        ])
        stackView.addArrangedSubview(fontTagContainer)
        stackView.addArrangedSubview(emptyLabel)
        stackView.addArrangedSubview(lightCapsule)
        stackView.addArrangedSubview(darkCapsule)

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])

        // Capsules start hidden; they appear only after a file is picked.
        lightCapsule.isHidden = true
        darkCapsule.isHidden = true
    }

    // MARK: State updates

    private func updateForNoFile() {
        replaceButton.setTitle("选择文件", for: .normal)
        fileNameLabel.text = "未选择文件"
        fileSizeLabel.text = "上浅下深 · 高度跟随内容"
        emptyLabel.isHidden = false
        lightCapsule.isHidden = true
        darkCapsule.isHidden = true
        clearButton.isEnabled = false
        shareButton.isEnabled = false
    }

    private func updateForFile(name: String, sizeText: String) {
        replaceButton.setTitle("更换文件", for: .normal)
        fileNameLabel.text = name
        fileSizeLabel.text = sizeText
        emptyLabel.isHidden = true
        lightCapsule.isHidden = false
        darkCapsule.isHidden = false
        clearButton.isEnabled = true
        shareButton.isEnabled = true
    }

    private func updateFontTag() {
        if let font = importedFont {
            fontTagLabel.text = "Aa  \(font.fileName)"
            fontTagView.isHidden = false
            fontTagContainer.isHidden = false
            importFontButton.setTitle("更换字体", for: .normal)
        } else {
            fontTagLabel.text = nil
            fontTagView.isHidden = true
            fontTagContainer.isHidden = true
            importFontButton.setTitle("导入字体", for: .normal)
        }
    }

    private func renderPreviews() {
        guard let html = htmlText else { return }
        lightCapsule.preview.load(html: html, font: importedFont)
        darkCapsule.preview.load(html: html, font: importedFont)
    }

    // MARK: Actions

    @objc private func replaceTapped() {
        presentPicker(purpose: .html)
    }

    @objc private func clearTapped() {
        // Clear clears the HTML preview only. The imported font stays,
        // so the next file still uses it; remove it with the font tag's ×.
        htmlText = nil
        htmlFileName = nil
        htmlFileURLForShare = nil
        lightCapsule.preview.clear()
        darkCapsule.preview.clear()
        updateForNoFile()
    }

    @objc private func importFontTapped() {
        presentPicker(purpose: .font)
    }

    @objc private func removeFontTapped() {
        importedFont = nil
        updateFontTag()
        renderPreviews()
    }

    @objc private func shareTapped() {
        guard let url = htmlFileURLForShare else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(activity, animated: true)
    }

    private func presentPicker(purpose: PickPurpose) {
        currentPickPurpose = purpose
        let types: [UTType]
        switch purpose {
        case .html:
            types = [.html]
        case .font:
            types = FontPickerTypes.allowed
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate

extension MainViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: url)
            switch currentPickPurpose {
            case .html:
                let text = String(decoding: data, as: UTF8.self)
                htmlText = text
                htmlFileName = url.lastPathComponent
                // Keep a shareable copy in the temporary directory.
                // The original picked file is not modified.
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
                try? data.write(to: tempURL, options: .atomic)
                htmlFileURLForShare = tempURL
                let kb = Double(data.count) / 1024.0
                let sizeText = kb >= 1024
                    ? String(format: "%.1f MB · 上浅下深 · 高度跟随内容", kb / 1024.0)
                    : String(format: "%.1f KB · 上浅下深 · 高度跟随内容", kb)
                updateForFile(name: url.lastPathComponent, sizeText: sizeText)
                renderPreviews()
            case .font:
                let name = url.lastPathComponent
                guard ImportedFont.isSupported(fileName: name) else {
                    showAlert(title: "不支持的字体", message: "只支持 .ttf / .otf / .woff / .woff2。")
                    return
                }
                let font = ImportedFont(fileName: name, data: data)
                font.registerIfPossible()
                importedFont = font
                updateFontTag()
                renderPreviews()
            }
        } catch {
            showAlert(title: "读取失败", message: error.localizedDescription)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // Nothing to do: the previous file and font stay as they were.
    }
}
