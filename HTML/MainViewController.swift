import UIKit
import UniformTypeIdentifiers
import CoreLocation

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

    // MARK: Build 4 adjustment state (global: both previews together)
    private var measuredContentHeight: CGFloat = 0
    private var fixedCardHeight: CGFloat? = nil
    private var horizontalOffset: CGFloat = 0
    private var verticalOffset: CGFloat = 0
    private var contentScalePercent: CGFloat = 100
    // Build 5: default 100 (solid pure white / pure black). Build 4
    // defaulted to 0 (fully transparent), so the light-grey page
    // showed through and white text on the dark preview was
    // almost unreadable on grey.
    private var backgroundAlphaPercent: CGFloat = 100
    private var webInteractive: Bool = true

    // Controls section views (built in buildControls()).
    private let controlsContainer = UIView()
    private let controlsStack = UIStackView()
    private var heightSlider: UISlider!
    private var heightValueLabel: UILabel!
    private var xSlider: UISlider!
    private var xValueLabel: UILabel!
    private var ySlider: UISlider!
    private var yValueLabel: UILabel!
    private var scaleSlider: UISlider!
    private var scaleValueLabel: UILabel!
    private var bgValueLabel: UILabel!
    private var interactiveSwitch: UISwitch!

    // MARK: Views

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let fileIconView = UIView()
    private let fileIconLabel = UILabel()
    private let fileNameLabel = UILabel()
    private let fileSizeLabel = UILabel()
    private let footerLabel = UILabel()

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

    // MARK: Build 7 location (user: "再给APP获取定位权限")
    //
    // When-In-Use only. Requested at launch and again when a file is
    // first loaded, but only while the status is .notDetermined, so
    // the system prompt appears at most once and a denial never loops
    // into repeated prompts or alerts: on denial the card simply keeps
    // showing whatever the HTML itself shows ("定位权限未开启" for a
    // card whose own script reports no location). On grant, previews
    // re-render once so a page script that calls geolocation on load
    // gets a chance to succeed with the new authorization.
    private let locationManager = CLLocationManager()

    private func requestLocationIfNeeded() {
        guard locationManager.authorizationStatus == .notDetermined else { return }
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Build 3 (user: "改纯色啊"): solid light-grey page background,
        // forced to light appearance so it stays light grey even when
        // the device is in system dark mode. In Build 2 the page had
        // no background at all, so in dark mode the whole page was
        // black and dark-grey top text on black was unreadable.
        // Forcing .light here also forces .label/.secondaryLabel to
        // their dark-on-light values, so top text stays readable.
        overrideUserInterfaceStyle = .light
        view.backgroundColor = UIColor(red: 0.91, green: 0.91, blue: 0.92, alpha: 1.0) // #E8E8EC
        scrollView.backgroundColor = UIColor(red: 0.91, green: 0.91, blue: 0.92, alpha: 1.0)
        buildLayout()
        updateForNoFile()
        requestLocationIfNeeded()
    }

    // MARK: Pill buttons (web layout, UIKit only)

    private func stylePillButton(_ button: UIButton, background: UIColor, titleColor: UIColor, bordered: Bool = false) {
        button.backgroundColor = background
        button.setTitleColor(titleColor, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.contentEdgeInsets = UIEdgeInsets(top: 9, left: 16, bottom: 9, right: 16)
        button.layer.cornerRadius = 17
        button.clipsToBounds = true
        if bordered {
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.systemGray4.cgColor
        }
    }

    // MARK: Layout (all UIKit, all system colours, no drawn decoration)

    private func buildLayout() {
        titleLabel.text = "HTML"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.textColor = .black
        titleLabel.numberOfLines = 1

        // Web layout 1:1, UIKit only: black </> file icon, then
        // filename (truncated in the middle) + size line.
        fileIconView.backgroundColor = .black
        fileIconView.layer.cornerRadius = 12
        fileIconView.clipsToBounds = true
        fileIconLabel.text = "</>"
        fileIconLabel.font = .systemFont(ofSize: 18, weight: .bold)
        fileIconLabel.textColor = .white
        fileIconLabel.textAlignment = .center

        fileNameLabel.font = .preferredFont(forTextStyle: .headline)
        fileNameLabel.textColor = .black
        fileNameLabel.numberOfLines = 1
        fileNameLabel.lineBreakMode = .byTruncatingMiddle

        fileSizeLabel.font = .preferredFont(forTextStyle: .subheadline)
        fileSizeLabel.textColor = .darkGray
        fileSizeLabel.numberOfLines = 1

        footerLabel.text = "上：浅色 · 下：深色 · 高度已贴合内容"
        footerLabel.font = .preferredFont(forTextStyle: .subheadline)
        footerLabel.textColor = .darkGray
        footerLabel.numberOfLines = 1
        footerLabel.textAlignment = .center
        footerLabel.isHidden = true

        // Pill buttons, not plain blue text links, as on the web page.
        replaceButton.setTitle("更换文件", for: .normal)
        replaceButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        stylePillButton(replaceButton, background: UIColor(red: 0.05, green: 0.47, blue: 0.42, alpha: 1), titleColor: .white)
        replaceButton.addTarget(self, action: #selector(replaceTapped), for: .touchUpInside)
        clearButton.setTitle("清除", for: .normal)
        stylePillButton(clearButton, background: .white, titleColor: .label, bordered: true)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        importFontButton.setTitle("Aa 导入字体", for: .normal)
        stylePillButton(importFontButton, background: .systemGray5, titleColor: .label)
        importFontButton.addTarget(self, action: #selector(importFontTapped), for: .touchUpInside)
        shareButton.setTitle("分享", for: .normal)
        stylePillButton(shareButton, background: .systemGray5, titleColor: .label)
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
        emptyLabel.textColor = .darkGray
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center

        // File header row: </> icon + (filename, size) column.
        fileIconView.addSubview(fileIconLabel)
        fileIconLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fileIconLabel.topAnchor.constraint(equalTo: fileIconView.topAnchor),
            fileIconLabel.leadingAnchor.constraint(equalTo: fileIconView.leadingAnchor),
            fileIconLabel.trailingAnchor.constraint(equalTo: fileIconView.trailingAnchor),
            fileIconLabel.bottomAnchor.constraint(equalTo: fileIconView.bottomAnchor),
            fileIconView.widthAnchor.constraint(equalToConstant: 48),
            fileIconView.heightAnchor.constraint(equalToConstant: 48),
        ])
        let fileInfoColumn = UIStackView(arrangedSubviews: [fileNameLabel, fileSizeLabel])
        fileInfoColumn.axis = .vertical
        fileInfoColumn.spacing = 2
        fileInfoColumn.alignment = .leading
        let fileHeaderRow = UIStackView(arrangedSubviews: [fileIconView, fileInfoColumn])
        fileHeaderRow.axis = .horizontal
        fileHeaderRow.spacing = 12
        fileHeaderRow.alignment = .center

        // Top bar, web order: font/share/clear pills on one row,
        // then the prominent teal Replace pill on its own row.
        let buttonRow = UIStackView(arrangedSubviews: [importFontButton, shareButton, clearButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 10
        buttonRow.alignment = .leading
        let replaceRow = UIStackView(arrangedSubviews: [replaceButton])
        replaceRow.axis = .horizontal
        replaceRow.spacing = 10
        replaceRow.alignment = .leading

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
        stackView.spacing = 14
        stackView.alignment = .fill
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(fileHeaderRow)
        stackView.addArrangedSubview(buttonRow)
        stackView.addArrangedSubview(replaceRow)
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
        buildControls()
        stackView.addArrangedSubview(controlsContainer)
        stackView.addArrangedSubview(footerLabel)

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

    // MARK: Build 4 controls (below the previews, global to both)

    // Build 6 (local only, NOT pushed): compact controls — user said
    // the panel is far too big. Buttons 38 -> 28pt, thumb 20 -> 16pt,
    // icons 28 -> 20pt, fonts one step down, descriptions one line,
    // all vertical spacing roughly halved, so each row is about half
    // the height it was in Build 5. Values/behaviour unchanged.
    private func roundButton(title: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        b.backgroundColor = .systemGray5
        b.setTitleColor(.black, for: .normal)
        b.layer.cornerRadius = 14
        b.clipsToBounds = true
        b.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            b.widthAnchor.constraint(equalToConstant: 28),
            b.heightAnchor.constraint(equalToConstant: 28),
        ])
        return b
    }

    private func makeSlider(min: Float, max: Float, value: Float) -> UISlider {
        let s = UISlider()
        s.minimumValue = min
        s.maximumValue = max
        s.value = value
        s.minimumTrackTintColor = .black
        s.maximumTrackTintColor = .systemGray4
        // Small thumb (16pt white circle) to match the smaller buttons.
        let size = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.setFillColor(UIColor.white.cgColor)
        ctx?.fillEllipse(in: CGRect(origin: .zero, size: size))
        ctx?.setStrokeColor(UIColor.systemGray3.cgColor)
        ctx?.setLineWidth(1)
        ctx?.strokeEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5))
        let thumb = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if let thumb = thumb {
            s.setThumbImage(thumb, for: .normal)
            s.setThumbImage(thumb, for: .highlighted)
        }
        return s
    }

    private func controlRow(icon: String, title: String, valueLabel: UILabel, description: String) -> UIStackView {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .black
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
        ])
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .black
        valueLabel.font = .preferredFont(forTextStyle: .subheadline)
        valueLabel.textColor = .black
        valueLabel.textAlignment = .right
        let header = UIStackView(arrangedSubviews: [iconView, titleLabel, valueLabel])
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center
        let desc = UILabel()
        desc.text = description
        desc.font = .preferredFont(forTextStyle: .caption1)
        desc.textColor = .darkGray
        desc.numberOfLines = 1
        desc.lineBreakMode = .byTruncatingTail
        let col = UIStackView(arrangedSubviews: [header, desc])
        col.axis = .vertical
        col.spacing = 2
        col.alignment = .fill
        return col
    }

    private func sliderRow(slider: UISlider, minus: UIButton, plus: UIButton) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [minus, slider, plus])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        return row
    }

    private func buildControls() {
        controlsContainer.backgroundColor = .white
        controlsContainer.layer.cornerRadius = 16
        controlsContainer.clipsToBounds = true
        controlsContainer.isHidden = true
        controlsStack.axis = .vertical
        controlsStack.spacing = 10
        controlsStack.alignment = .fill
        controlsContainer.addSubview(controlsStack)
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controlsStack.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 10),
            controlsStack.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 10),
            controlsStack.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -10),
            controlsStack.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -10),
        ])

        // 1. 卡片高度
        heightValueLabel = UILabel()
        heightValueLabel.text = "0"
        heightSlider = makeSlider(min: 0, max: 1000, value: 0)
        heightSlider.addTarget(self, action: #selector(heightSliderChanged), for: .valueChanged)
        let hMinus = roundButton(title: "−")
        hMinus.addTarget(self, action: #selector(heightMinus), for: .touchUpInside)
        let hPlus = roundButton(title: "+")
        hPlus.addTarget(self, action: #selector(heightPlus), for: .touchUpInside)
        let hCol = controlRow(icon: "arrow.up.arrow.down", title: "卡片高度", valueLabel: heightValueLabel, description: "网页内容有多高，胶囊就是多高；调高了从底边往上长，超出部分看不到")
        let hBlock = UIStackView(arrangedSubviews: [hCol, sliderRow(slider: heightSlider, minus: hMinus, plus: hPlus)])
        hBlock.axis = .vertical; hBlock.spacing = 5
        controlsStack.addArrangedSubview(hBlock)

        // 2. 横向偏移
        xValueLabel = UILabel(); xValueLabel.text = "0"
        xSlider = makeSlider(min: -200, max: 200, value: 0)
        xSlider.addTarget(self, action: #selector(xSliderChanged), for: .valueChanged)
        let xMinusBtn = roundButton(title: "−"); xMinusBtn.addTarget(self, action: #selector(xMinus), for: .touchUpInside)
        let xPlusBtn = roundButton(title: "+"); xPlusBtn.addTarget(self, action: #selector(xPlus), for: .touchUpInside)
        let xCol = controlRow(icon: "arrow.left.arrow.right", title: "横向偏移", valueLabel: xValueLabel, description: "把网页内容左右挪一挪，填负数往左；胶囊本身不动")
        let xBlock = UIStackView(arrangedSubviews: [xCol, sliderRow(slider: xSlider, minus: xMinusBtn, plus: xPlusBtn)])
        xBlock.axis = .vertical; xBlock.spacing = 5
        controlsStack.addArrangedSubview(xBlock)

        // 3. 纵向偏移
        yValueLabel = UILabel(); yValueLabel.text = "0"
        ySlider = makeSlider(min: -200, max: 200, value: 0)
        ySlider.addTarget(self, action: #selector(ySliderChanged), for: .valueChanged)
        let yMinusBtn = roundButton(title: "−"); yMinusBtn.addTarget(self, action: #selector(yMinus), for: .touchUpInside)
        let yPlusBtn = roundButton(title: "+"); yPlusBtn.addTarget(self, action: #selector(yPlus), for: .touchUpInside)
        let yCol = controlRow(icon: "arrow.up.arrow.down", title: "纵向偏移", valueLabel: yValueLabel, description: "把网页内容上下挪一挪，填负数往上；胶囊本身不动")
        let yBlock = UIStackView(arrangedSubviews: [yCol, sliderRow(slider: ySlider, minus: yMinusBtn, plus: yPlusBtn)])
        yBlock.axis = .vertical; yBlock.spacing = 5
        controlsStack.addArrangedSubview(yBlock)

        // 4. 内容缩放
        scaleValueLabel = UILabel(); scaleValueLabel.text = "100"
        scaleSlider = makeSlider(min: 50, max: 200, value: 100)
        scaleSlider.addTarget(self, action: #selector(scaleSliderChanged), for: .valueChanged)
        let sMinus = roundButton(title: "−"); sMinus.addTarget(self, action: #selector(scaleMinus), for: .touchUpInside)
        let sPlus = roundButton(title: "+"); sPlus.addTarget(self, action: #selector(scalePlus), for: .touchUpInside)
        let sCol = controlRow(icon: "arrow.up.left.and.arrow.down.right", title: "内容缩放", valueLabel: scaleValueLabel, description: "把网页内容放大或缩小，100 是原样；胶囊本身不变")
        let sBlock = UIStackView(arrangedSubviews: [sCol, sliderRow(slider: scaleSlider, minus: sMinus, plus: sPlus)])
        sBlock.axis = .vertical; sBlock.spacing = 5
        controlsStack.addArrangedSubview(sBlock)

        // 5. 背景透明度 (stepper only, no slider, as in screenshot)
        // Build 5 default 100 (solid), not 0.
        // User correction: the -/+ buttons live on the TITLE row itself,
        // on ONE line with icon + title + value — no separate button row below.
        bgValueLabel = UILabel(); bgValueLabel.text = "100"
        let bgMinusBtn = roundButton(title: "−"); bgMinusBtn.addTarget(self, action: #selector(bgMinus), for: .touchUpInside)
        let bgPlusBtn = roundButton(title: "+"); bgPlusBtn.addTarget(self, action: #selector(bgPlus), for: .touchUpInside)
        let bgIconView = UIImageView(image: UIImage(systemName: "paintpalette"))
        bgIconView.tintColor = .black
        bgIconView.contentMode = .scaleAspectFit
        bgIconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bgIconView.widthAnchor.constraint(equalToConstant: 20),
            bgIconView.heightAnchor.constraint(equalToConstant: 20),
        ])
        let bgTitleLabel = UILabel()
        bgTitleLabel.text = "背景透明度"
        bgTitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        bgTitleLabel.textColor = .black
        bgValueLabel.font = .preferredFont(forTextStyle: .subheadline)
        bgValueLabel.textColor = .black
        bgValueLabel.textAlignment = .right
        let bgHeader = UIStackView(arrangedSubviews: [bgIconView, bgTitleLabel, bgValueLabel, bgMinusBtn, bgPlusBtn])
        bgHeader.axis = .horizontal; bgHeader.spacing = 8; bgHeader.alignment = .center
        let bgDesc = UILabel()
        bgDesc.text = "网页没画东西的地方透出的底色，0 是完全透明，100 是实色"
        bgDesc.font = .preferredFont(forTextStyle: .caption1)
        bgDesc.textColor = .darkGray
        bgDesc.numberOfLines = 1
        bgDesc.lineBreakMode = .byTruncatingTail
        let bgBlock = UIStackView(arrangedSubviews: [bgHeader, bgDesc])
        bgBlock.axis = .vertical; bgBlock.spacing = 2
        controlsStack.addArrangedSubview(bgBlock)

        // 6. 网页可交互
        let swLabel = UILabel(); swLabel.text = "开"
        interactiveSwitch = UISwitch()
        interactiveSwitch.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        interactiveSwitch.isOn = true
        interactiveSwitch.addTarget(self, action: #selector(interactiveChanged), for: .valueChanged)
        let swCol = controlRow(icon: "message", title: "网页可交互", valueLabel: swLabel, description: "关 = 网页只是装饰，点它等于点到后面的东西；开 = 网页自己接着点击")
        // Replace the value label in the header with the switch: rebuild header row simply by appending switch to the block.
        let swRow = UIStackView(arrangedSubviews: [swCol, interactiveSwitch])
        swRow.axis = .horizontal; swRow.spacing = 8; swRow.alignment = .center
        controlsStack.addArrangedSubview(swRow)

        // Height callbacks: light preview drives the default; dark mirrors it.
        lightCapsule.preview.onHeightMeasured = { [weak self] h in self?.measuredHeightChanged(h) }
        darkCapsule.preview.onHeightMeasured = { [weak self] h in self?.measuredHeightChanged(h) }
    }

    private func measuredHeightChanged(_ h: CGFloat) {
        guard h > 0 else { return }
        // Take the larger of the two previews (same content, should match).
        if h > measuredContentHeight { measuredContentHeight = h }
        if fixedCardHeight == nil {
            heightSlider.value = Float(measuredContentHeight)
            heightValueLabel.text = "\(Int(measuredContentHeight))"
            applyAdjustments()
        }
    }

    private func applyAdjustments() {
        let capsuleHeight = fixedCardHeight ?? measuredContentHeight
        for capsule in [lightCapsule, darkCapsule] {
            capsule.setCapsuleHeight(capsuleHeight)
            capsule.setBackgroundAlpha(backgroundAlphaPercent / 100)
            capsule.preview.applyTransform(offsetX: horizontalOffset, offsetY: verticalOffset, scale: contentScalePercent / 100)
            capsule.preview.setInteractive(webInteractive)
        }
    }

    private func setHeight(_ v: CGFloat) {
        let clamped = min(max(v, 0), 1000)
        fixedCardHeight = clamped
        heightSlider.value = Float(clamped)
        heightValueLabel.text = "\(Int(clamped))"
        applyAdjustments()
    }

    // Build 5: every -/+ button steps by exactly 1 per tap.
    // Slider drag still moves continuously; buttons are strictly +/-1.
    @objc private func heightSliderChanged() { setHeight(CGFloat(heightSlider.value)) }
    @objc private func heightMinus() { setHeight((fixedCardHeight ?? measuredContentHeight) - 1) }
    @objc private func heightPlus() { setHeight((fixedCardHeight ?? measuredContentHeight) + 1) }

    @objc private func xSliderChanged() { horizontalOffset = CGFloat(xSlider.value); xValueLabel.text = "\(Int(horizontalOffset))"; applyAdjustments() }
    @objc private func xMinus() { xSlider.value -= 1; xSliderChanged() }
    @objc private func xPlus() { xSlider.value += 1; xSliderChanged() }

    @objc private func ySliderChanged() { verticalOffset = CGFloat(ySlider.value); yValueLabel.text = "\(Int(verticalOffset))"; applyAdjustments() }
    @objc private func yMinus() { ySlider.value -= 1; ySliderChanged() }
    @objc private func yPlus() { ySlider.value += 1; ySliderChanged() }

    @objc private func scaleSliderChanged() { contentScalePercent = CGFloat(scaleSlider.value); scaleValueLabel.text = "\(Int(contentScalePercent))"; applyAdjustments() }
    @objc private func scaleMinus() { scaleSlider.value -= 1; scaleSliderChanged() }
    @objc private func scalePlus() { scaleSlider.value += 1; scaleSliderChanged() }

    // Build 6 (user-approved): background transparency is the ONE exception
    // to the +/-1 rule — it steps by exactly 5 per tap, clamped 0...100.
    // All other controls (height, x, y, scale) remain strictly +/-1.
    @objc private func bgMinus() { backgroundAlphaPercent = min(max(backgroundAlphaPercent - 5, 0), 100); bgValueLabel.text = "\(Int(backgroundAlphaPercent))"; applyAdjustments() }
    @objc private func bgPlus() { backgroundAlphaPercent = min(max(backgroundAlphaPercent + 5, 0), 100); bgValueLabel.text = "\(Int(backgroundAlphaPercent))"; applyAdjustments() }

    @objc private func interactiveChanged() { webInteractive = interactiveSwitch.isOn; applyAdjustments() }

    private func resetAdjustmentsForNewFile() {
        measuredContentHeight = 0
        fixedCardHeight = nil
        heightSlider.value = 0
        heightValueLabel.text = "0"
        // Build 5: a new file resets background transparency to
        // 100 (solid pure white / pure black) by default.
        backgroundAlphaPercent = 100
        bgValueLabel.text = "100"
        // Other controls are global user preferences and stay as set.
        applyAdjustments()
    }

    // MARK: State updates

    private func updateForNoFile() {
        replaceButton.setTitle("选择文件", for: .normal)
        fileNameLabel.text = "未选择文件"
        fileSizeLabel.text = "上浅下深 · 高度跟随内容"
        emptyLabel.isHidden = false
        lightCapsule.isHidden = true
        darkCapsule.isHidden = true
        controlsContainer.isHidden = true
        footerLabel.isHidden = true
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
        controlsContainer.isHidden = false
        footerLabel.isHidden = false
        clearButton.isEnabled = true
        shareButton.isEnabled = true
    }

    private func updateFontTag() {
        if let font = importedFont {
            fontTagLabel.text = "Aa  \(font.fileName)"
            fontTagView.isHidden = false
            fontTagContainer.isHidden = false
            importFontButton.setTitle("Aa 更换字体", for: .normal)
        } else {
            fontTagLabel.text = nil
            fontTagView.isHidden = true
            fontTagContainer.isHidden = true
            importFontButton.setTitle("Aa 导入字体", for: .normal)
        }
    }

    private func renderPreviews() {
        guard let html = htmlText else { return }
        requestLocationIfNeeded()
        lightCapsule.preview.load(html: html, font: importedFont)
        darkCapsule.preview.load(html: html, font: importedFont)
        // Whole-content follow (Build 7): re-apply the current card
        // adjustments after every reload, so avatar, text and icons
        // keep moving/scaling/clipping with the card, not just the
        // capsule background.
        applyAdjustments()
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

// MARK: - CLLocationManagerDelegate (Build 7)

extension MainViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Grant: give a loaded page script one fresh load, so its
            // geolocation lookup can succeed now. No-op if no file.
            if htmlText != nil { renderPreviews() }
        case .denied, .restricted:
            // Denial is final and silent: no alert, no re-prompt loop.
            // The card keeps showing whatever its own HTML shows.
            break
        default:
            break
        }
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
                resetAdjustmentsForNewFile()
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
