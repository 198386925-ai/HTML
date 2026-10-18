import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var api: AdminAPI
    @EnvironmentObject var display: AppDisplaySettings
    @State private var server = ""
    @State private var saved = false
    @State private var showImporter = false
    @State private var importError: String?

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
                        Text(e).font(.caption).foregroundColor(.red)
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
                        Text("已保存，下次登录生效").font(.footnote).foregroundColor(.green)
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
            .onAppear { server = api.serverBase; saved = false }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.font],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        if display.importFont(from: url) == nil {
                            importError = "导入失败，请确认是有效的字体文件"
                        } else {
                            importError = nil
                        }
                    }
                case .failure:
                    importError = "选择文件失败"
                }
            }
        }
    }
}
