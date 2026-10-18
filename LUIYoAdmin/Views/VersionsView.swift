import SwiftUI

/// 版本管理：与网页 versions 面板一致（登记/禁用版本 + 已登记版本）
struct VersionsView: View {
    @EnvironmentObject var api: AdminAPI
    @State private var list: [AppVersion] = []
    @State private var loading = false
    @State private var error: String?
    @State private var version = ""
    @State private var note = ""
    @State private var message = "请下载正版使用"
    @State private var busy = false

    var body: some View {
        NavigationView {
            List {
                Section("登记 / 禁用版本") {
                    TextField("版本号（如 1.0.7）", text: $version)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("备注（可选）", text: $note)
                    TextField("提示信息", text: $message)
                    HStack {
                        Button(busy ? "处理中…" : "登记版本") { doOp(op: "add") }
                            .disabled(busy || version.isEmpty)
                        Button(busy ? "处理中…" : "禁用版本") { doOp(op: "block") }
                            .disabled(busy || version.isEmpty)
                            .tint(.orange)
                    }
                    if let e = error {
                        Text(e).foregroundColor(.red).font(.footnote)
                    }
                }

                Section("已登记版本") {
                    if loading && list.isEmpty {
                        ProgressView()
                    } else if list.isEmpty {
                        Text("暂无").foregroundColor(.secondary).font(.footnote)
                    } else {
                        ForEach(list) { v in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(v.version).font(.system(.headline, design: .monospaced))
                                    Spacer()
                                    Text(v.blocked ? "已禁用" : "正常")
                                        .font(.caption)
                                        .foregroundColor(v.blocked ? .red : .green)
                                }
                                if !v.note.isEmpty {
                                    Text(v.note).font(.caption).foregroundColor(.secondary)
                                }
                                if !v.message.isEmpty {
                                    Text("提示：" + v.message).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                if v.blocked {
                                    Button("解禁") { opOnList(op: "unblock", version: v.version) }
                                        .tint(.green)
                                } else {
                                    Button("禁用") { opOnList(op: "block", version: v.version) }
                                        .tint(.orange)
                                }
                                Button("删除", role: .destructive) {
                                    opOnList(op: "delete", version: v.version)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("版本")
            .refreshable { await reload() }
            .task { await reload() }
        }
    }

    private func doOp(op: String) {
        busy = true
        error = nil
        Task {
            do {
                try await api.versionAction(op: op, version: version,
                                            note: note, message: message)
                version = ""
                note = ""
                await reload()
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }

    private func opOnList(op: String, version: String) {
        Task {
            do {
                try await api.versionAction(op: op, version: version)
                await reload()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func reload() async {
        loading = true
        do { list = try await api.versions() }
        catch { self.error = error.localizedDescription }
        loading = false
    }
}
