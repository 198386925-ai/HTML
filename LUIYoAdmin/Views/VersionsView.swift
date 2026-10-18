import SwiftUI

/// 版本控制：与网页 versions 面板一致
/// 登记/禁用版本（版本号/提示文案/原因/立即禁用）+ 已登记版本（版本/状态/提示/原因/操作）
struct VersionsView: View {
    @EnvironmentObject var api: AdminAPI
    @State private var list: [AppVersion] = []
    @State private var loading = false
    @State private var error: String?
    @State private var version = ""
    @State private var note = ""
    @State private var message = "请下载正版使用"
    @State private var blockNow = true
    @State private var busy = false

    var body: some View {
        NavigationView {
            List {
                Section("登记 / 禁用版本") {
                    Text("客户端联网后会自动同步版本号到本页。新版本出现后可直接禁用或恢复；禁用后所有该版本 App 无法使用并提示下载正版。也可手动补登记。")
                        .font(.caption).foregroundColor(.secondary)
                        .listRowSeparator(.hidden)
                    LabeledField(label: "版本号", placeholder: "例如 1.0.5", text: $version)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    LabeledField(label: "提示文案", placeholder: "请下载正版使用", text: $message)
                    LabeledField(label: "原因", placeholder: "可选", text: $note)
                    Toggle("立即禁用此版本", isOn: $blockNow)
                        .listRowSeparator(.hidden)
                    Button(busy ? "处理中…" : "保存版本") {
                        doOp(op: blockNow ? "block" : "add")
                    }
                    .disabled(busy || version.isEmpty)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    if let e = error {
                        Text(e).foregroundColor(.red).font(.footnote)
                            .listRowSeparator(.hidden)
                    }
                }

                Section("已登记版本") {
                    if loading && list.isEmpty {
                        ProgressView()
                            .listRowSeparator(.hidden)
                    } else if list.isEmpty {
                        Text("暂无记录。请先添加需要管控的旧版本号。")
                            .foregroundColor(.secondary).font(.footnote)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(list) { v in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(v.version).font(.system(.headline))
                                    Spacer()
                                    Text(v.blocked ? "已禁用" : "允许")
                                        .font(.caption)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(v.blocked ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                                        .foregroundColor(v.blocked ? .red : .green)
                                        .cornerRadius(8)
                                }
                                if !v.message.isEmpty {
                                    Text("提示：" + v.message).font(.caption).foregroundColor(.secondary)
                                }
                                if !v.note.isEmpty {
                                    Text("原因：" + v.note).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                                Button("编辑") {
                                    version = v.version
                                    message = v.message
                                    note = v.note
                                    blockNow = v.blocked
                                }
                                .tint(.blue)
                                if v.blocked {
                                    Button("恢复") { opOnList(op: "unblock", version: v.version) }
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
            .navigationBarTitleDisplayMode(.inline)
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
