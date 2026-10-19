import SwiftUI
import UIKit
import UniformTypeIdentifiers



/// UIKit 文档选择器（绕过 SwiftUI fileImporter 在 TabView 中的 bug）
struct FontDocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL?) -> Void
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL?) -> Void
        init(onPick: @escaping (URL?) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var api: AdminAPI
    @EnvironmentObject var display: AppDisplaySettings
    @State private var server = ""
    @State private var saved = false
    @State private var showImporter = false
    @State private var importError: String?
    @State private var importMessage: String?
    @State private var showImportAlert = false

    var body: some View {
        NavigationView {
            Form {
                // 显示设置（全局）
                Section("显示") {
                    Picker("字体大小", selection: $display.fontSize) {
                        ForEach(DeviceFontSize.allCases, id: \.self) { fs in
                            Text(fs.title).tag(fs)
                        }
                    }
                    Picker("布局疏密", selection: $display.density) {
                        ForEach(DeviceDensity.allCases, id: \.self) { d in
                            Text(d.title).tag(d)
                        }
                    }
                }
                .onChange(of: display.fontSize) { _ in display.save() }
                .onChange(of: display.density) { _ in display.save() }

                // 自定义字体
                Section(header: Text("自定义字体"), footer: Text("导入字体文件，全局生效。")) {
                    Button {
                        display.useSystemFont()
                    } label: {
                        HStack {
                            Text("系统默认")
                            Spacer()
                            if display.customFontName == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)

                    ForEach(display.importedFonts, id: \.self) { psName in
                        HStack {
                            Button {
                                display.useFont(psName)
                            } label: {
                                HStack {
                                    Text(psName)
                                        .font(.custom(psName, size: 16))
                                    Spacer()
                                    if display.customFontName == psName {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("删除", role: .destructive) {
                                display.deleteFont(psName)
                            }
                        }
                    }

                    Button {
                        showImporter = true
                    } label: {
                        Label("导入字体", systemImage: "square.and.arrow.down")
                    }


                    if let e = importError {
                        Text(e).font(display.fCaption).foregroundColor(.red)
                    }
                }

                Section("服务器") {
                    TextField("https://…/luiyo", text: $server)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("保存") {
                        api.saveServer(server)
                        saved = true
                    }
                    if saved {
                        Text("已保存，下次登录生效").font(display.fFootnote).foregroundColor(.green)
                    }
                }
                Section {
                    Button("退出登录", role: .destructive) {
                        api.logout()
                    }
                }
                Section("关于") {
                    HStack { Text("应用"); Spacer(); Text("LUIYo后台 1.0.0") }
                    HStack { Text("构建"); Spacer(); Text("0") }
                }
            }
            .navigationTitle("设置")
            .alert("字体导入", isPresented: $showImportAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(importMessage ?? "")
            }
            .onAppear { server = api.serverBase; saved = false }
            .sheet(isPresented: $showImporter) {
                FontDocumentPicker { url in
                    showImporter = false
                    guard let url = url else {
                        importMessage = "已取消选择"
                        showImportAlert = true
                        return
                    }
                    let (name, error) = display.importFontDetailed(from: url)
                    if let name = name {
                        importMessage = "导入成功"
                        display.useFont(name)  // 导入后自动选中
                    } else {
                        importMessage = "导入失败"
                    }
                    if let error = error {
                        importMessage = importMessage! + ": " + error
                    }
                    showImportAlert = true
                }
            }
    }
}
}
