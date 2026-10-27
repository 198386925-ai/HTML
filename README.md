# HTML — HTML 上传预览（UIKit-only）

把一个 `.html` 文件整页预览：上面浅色、下面深色，两个独立胶囊
分开，高度跟随卡片内容，支持导入字体。胶囊用 iOS 26 原生液态玻璃
（UIKit `UIGlassEffect`），坚决不自绘玻璃。

- App 名：HTML
- 包名：com.youyou.html
- 版本：1.0.0，构建号：1（下一构建先把 `HTML/Info.plist` 里的
  `CFBundleVersion` 加 1，再触发构建；版本号变时构建号从 0 重置，
  这是沿用的 IPA 常设规则）
- 部署目标：iOS 26.0（原生液态玻璃的要求；iOS 26 以下装不上，
  这是有意的，不是兼容性遗漏）
- 仓库：https://github.com/198386925-ai/HTML
  （原 `LUIYoAdmin-Build`，已改名；旧 LUIYoAdmin 源码在新提交里
  删除，见 `DELETE_OLD_SOURCE.md`，旧代码仍在 git 历史里）

## 界面（全部 UIKit，零 SwiftUI）

- 顶栏：文件名、文件大小、选择/更换文件、清除、导入/更换字体、
  分享（iPhone 上没有“新窗口”，分享是对应的 trivial 替代）。
- 字体标签：导入后显示字体文件名，× 可移除，移除后重新按原页面
  字体渲染；清除只清 HTML，不清字体。
- 预览：两个 `WKWebView`，上面 `color-scheme: light` + 浅色 trait，
  下面 `color-scheme: dark` + 深色 trait，渲染同一个上传文件。
  两个胶囊在垂直 Stack 里用 18pt 间距分开，不重叠、不淡入遮罩。
- 字体：`.ttf/.otf/.woff/.woff2`，以 data URL `@font-face` 注入两个
  WebView；ttf/otf 还会尽力用 CoreText 注册（woff/woff2 注册不了，
  但 WebKit 的 `@font-face` 能用，所以注册失败不影响预览）。
- 上传的 HTML 主体本身不改透明度、不改背景：注入的只有
  color-scheme、字体、缺失时补一个 viewport meta、以及量高脚本。

## 原生液态玻璃（硬性规则）

`HTML/GlassCapsuleView.swift` 是唯一放玻璃的地方：

- `UIGlassEffect(style: .regular)` + `UIVisualEffectView(effect:)`，
  `isInteractive = false`，浅色胶囊 tint `.white`、深色胶囊 tint
  `.black`（tintColor 是 `UIGlassEffect` 自身的属性，不是自绘填充）。
- WebView 放在 effectView 的 contentView 里，四边各留 3pt，露出
  的 3pt 边缘就是系统玻璃；胶囊自身 backgroundColor 是 `.clear`。
- 没有渐变层、没有描边、没有阴影、没有高光自绘。唯一设的 layer
  属性是 cornerRadius，那只是把系统效果裁成胶囊形状的几何裁剪，
  不画任何材质。grep 验证：`GlassCapsuleView.swift` 里没有
  `CAGradientLayer`、`borderWidth`、`shadow`、`backgroundColor` 填充
  玻璃的代码（`.clear` 除外）。

## 高度跟随内容（为什么不用 scrollHeight）

`HTML/PreviewWebView.swift` 的量高脚本不以 `body.scrollHeight` 为准：
一个 `min-height: 100vh` 的外壳会让 scrollHeight 永远等于视口高，
卡片下面就永远留大片空白。它只统计“有实际内容”的元素——可见
叶子元素、图片，以及自身有非透明背景/边框/阴影的容器——取它们
最下面的底边作为内容高度；WebView 自身不滚动，外层 ScrollView
滚动；量高在 load 后 120/450/1000ms、resize、DOM 变化时重测，
变化不足 1pt 时不更新。

已知限制：页面如果不用 `@media (prefers-color-scheme)`、而是用
自己写的深色 class 切换，深色预览仍会按页面自己的逻辑显示，
那是页面本身的逻辑，不是预览的 bug；真正很长的页面会按内容长
高，外层滚动查看（上限 4000pt 是防脚本失控，不是内容上限的
设计目标，超长页面请以实测为准）。

## 构建（GitHub Actions，和 LUIYo 同一套流程）

- 本地/CI 构建脚本：`scripts/build-ipa.sh`
  （工程 `HTML.xcodeproj`，Scheme `HTML`，Release，unsigned，
  要求 iOS 26 SDK，产出 `output/HTML-1.0.0-Build(1).ipa` 和
  `output/HTML-1.0.0-Build(1)-src.zip`）。
- IPA 命名：`HTML-1.0.0-Build(n)`；源码备份 zip：同名 `-src.zip`，
  每次 IPA 交付都附带干净源码 zip（只含真实源码，排除
  build/、output/、.git）。
- 工作流：复用仓库里已有的 `.github/workflows/build-ipa.yml`
  （原来 Build LUIYoAdmin IPA 的那份），只改了 App 名、工程名、
  并发组、产物名，见本目录 `.github/workflows/build-ipa.yml`。

## 推送步骤（下一步需要用户做的事，按顺序）

1. 仓库改名已完成：`198386925-ai/LUIYoAdmin-Build` →
   `198386925-ai/HTML`（API 返回 200，MCP 复查新名已生效）。
2. 推送源码（API 可推，token 是 repo 权限）：把本目录内容推到
   `main`，同时按 `DELETE_OLD_SOURCE.md` 删掉旧 `LUIYoAdmin/`、
   `LUIYoAdmin.xcodeproj/`，替换 `scripts/build-ipa.sh` 和
   `README.md`。不要强推、不要改写历史。
3. 工作流只能在网页端改：打开
   https://github.com/198386925-ai/HTML/blob/main/.github/workflows/build-ipa.yml
   点编辑，把本目录 `.github/workflows/build-ipa.yml` 的内容粘贴
   进去保存。API 推这个路径会 404，不要硬推。
4. 工作流确认无误后，再推一次触发构建（或在 Actions 里手动
   workflow_dispatch）。在工作流成功之前，不要声称 IPA 已建成、
   已交付。本步交付只是可推送的源码，不是已建成的 IPA。
5. 图标：`HTML/Assets.xcassets/AppIcon.appiconset/` 里目前是
   纯色占位图标（构建能通过），正式交付前请换成真正的 App 图标。

## 首次 CI 即编译验证

本机没有 macOS 编译器，源码是按 Swift / UIKit / WebKit API
逐行复核的，没有实际编译过。第一次 Actions 运行就是编译验证：
如果它报错，把 `error:` 行原样发回来，按行修，不要盲改。
