import SwiftUI

/// 版本控制：设计三风格（深紫底 + 白色圆卡）
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

    private let purple = Color(red: 0.29, green: 0.23, blue: 1.0)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 标题
                HStack {
                    Text("版本")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // 登记卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text("登记 / 禁用版本")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("客户端联网后会自动同步版本号到本页。新版本出现后可直接禁用或恢复；禁用后所有该版本 App 无法使用并提示下载正版。也可手动补登记。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    PurpleField(label: "版本号", placeholder: "例如 1.0.5", text: $version)
                    PurpleField(label: "提示文案", placeholder: "请下载正版使用", text: $message)
                    PurpleField(label: "原因", placeholder: "可选", text: $note)

                    Toggle("立即禁用此版本", isOn: $blockNow)
                        .tint(purple)

                    Button {
                        doOp(op: blockNow ? "block" : "add")
                    } label: {
                        Text(busy ? "处理中…" : "保存版本")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(purple)
                            .cornerRadius(16)
                    }
                    .disabled(busy || version.isEmpty)
                    .opacity(busy || version.isEmpty ? 0.5 : 1.0)

                    if let e = error {
                        Text(e).foregroundColor(.red).font(.footnote)
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(24)
                .padding(.horizontal, 16)

                // 已登记版本
                VStack(alignment: .leading, spacing: 12) {
                    Text("已登记版本")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if loading && list.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if list.isEmpty {
                        Text("暂无记录。请先添加需要管控的旧版本号。")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    } else {
                        ForEach(list) { v in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(v.version)
                                        .font(.system(.headline, design: .monospaced))
                                    Spacer()
                                    Text(v.blocked ? "已禁用" : "允许")
                                        .font(.caption).bold()
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(v.blocked ? Color.red : Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                if !v.message.isEmpty {
                                    Text("提示：" + v.message)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if !v.note.isEmpty {
                                    Text("原因：" + v.note)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                HStack(spacing: 8) {
                                    Spacer()
                                    Button("编辑") {
                                        version = v.version
                                        message = v.message
                                        note = v.note
                                        blockNow = v.blocked
                                    }
                                    .font(.caption)
                                    .foregroundColor(purple)
                                    if v.blocked {
                                        Button("恢复") { opOnList(op: "unblock", version: v.version) }
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else {
                                        Button("禁用") { opOnList(op: "block", version: v.version) }
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    Button("删除") { opOnList(op: "delete", version: v.version) }
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(24)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(purple.ignoresSafeArea())
        .refreshable { await reload() }
        .task { await reload() }
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

/// 设计三风格输入框
struct PurpleField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)
            TextField(placeholder, text: $text)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }
}
