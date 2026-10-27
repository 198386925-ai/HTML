# 旧源码删除清单（LUIYoAdmin-Build → HTML）

本文件不是 App 代码，它是推送时要删掉的旧文件清单。
删除方式是普通新提交，不是强推、不是改写历史：旧代码仍留在
git 历史里（旧提交 f99b43132c353010aa255c197497e8e81d5b33d9 之前），
随时可以从历史里找回。

## 删掉整个目录（旧 LUIYoAdmin App 的全部源码）

- `LUIYoAdmin/` —— 旧 App 源码全部，包括：
  - `LUIYoAdmin/API/`（旧后端接口）
  - `LUIYoAdmin/Assets.xcassets/`（旧图标资源）
  - `LUIYoAdmin/ContentView.swift`（旧 SwiftUI 界面——新 App 零 SwiftUI）
  - `LUIYoAdmin/Info.plist`（旧包信息）
  - `LUIYoAdmin/LUIYoAdminApp.swift`（旧 SwiftUI 入口）
  - `LUIYoAdmin/Models.swift`
  - `LUIYoAdmin/Support/`（旧支撑代码）
  - `LUIYoAdmin/Views/`（旧 SwiftUI 界面）

- `LUIYoAdmin.xcodeproj/` —— 旧工程文件全部。

## 替换（不是删除后留空）

- `scripts/build-ipa.sh` —— 换成本目录的新版（工程 HTML、App 名 HTML、
  iOS 26 SDK 校验、同时产出 IPA 和 `-src.zip`）。
- `README.md` —— 换成本目录的新版。

## 保留，但只能在网页端改（不要用 API 推）

- `.github/workflows/build-ipa.yml` —— 已存在的工作流，复用它。
  本目录 `.github/workflows/build-ipa.yml` 是已改好 App 名的副本，
  只能在 GitHub 网页端编辑/新建该文件时粘贴进去。
  API 推 `.github/workflows/*` 会 404（token 只有 repo 权限，没有
  workflow 权限），不要硬推、不要绕过。

## 新增（本次 HTML App 的全部源码）

- `HTML/` —— AppDelegate、SceneDelegate、MainViewController、
  GlassCapsuleView、PreviewWebView、FontStore、Info.plist、
  Assets.xcassets（占位图标，见 README）。
- `HTML.xcodeproj/` —— 新工程和 Scheme。
- `scripts/build-ipa.sh`、`README.md`、`.gitignore`（见上）。
