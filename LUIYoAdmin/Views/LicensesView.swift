import SwiftUI

/// 卡密管理：与网页 licenses 面板一致（激活码列表 + 搜索 + 停用/启用/删除）
struct LicensesView: View {
    @EnvironmentObject var api: AdminAPI
    @State private var list: [License] = []
    @State private var loading = false
    @State private var error: String?
    @State private var query = ""
    @State private var confirmDelete: License?

    var filtered: [License] {
        guard !query.isEmpty else { return list }
        let q = query.lowercased()
        return list.filter {
            ($0.code ?? "").lowercased().contains(q)
            || $0.label.lowercased().contains(q)
            || String($0.id).contains(q)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if loading && list.isEmpty {
                    ProgressView()
                } else {
                    List(filtered) { lic in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("#\(lic.id)").font(.headline)
                                if !lic.label.isEmpty {
                                    Text(lic.label).font(.subheadline).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(lic.statusText)
                                    .font(.caption)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(lic.statusText == "正常"
                                        ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                    .foregroundColor(lic.statusText == "正常" ? .green : .red)
                                    .cornerRadius(8)
                            }
                            if let code = lic.code, !code.isEmpty {
                                HStack {
                                    Text(code).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                                    Spacer()
                                    Button { UIPasteboard.general.string = code } label: {
                                        Image(systemName: "doc.on.doc").font(.caption)
                                    }
                                }
                            } else {
                                Text("旧卡密明文不可恢复").font(.caption).foregroundColor(.secondary)
                            }
                            HStack {
                                Text("设备 \(lic.deviceCount)/\(lic.maxDevices)").font(.caption)
                                Spacer()
                                if let e = lic.expiresAt {
                                    Text("到期 " + dateStr(e)).font(.caption)
                                } else {
                                    Text("永久").font(.caption)
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                        .swipeActions(edge: .trailing) {
                            if lic.disabled {
                                Button("启用") { act(lic, op: "enable") }.tint(.green)
                            } else {
                                Button("停用") { act(lic, op: "disable") }.tint(.orange)
                            }
                            Button("删除", role: .destructive) { confirmDelete = lic }
                        }
                    }
                    .refreshable { await reload() }
                }
            }
            .navigationTitle("卡密")
            .searchable(text: $query, prompt: "搜索卡密编号或备注")
            .task { await reload() }
            .alert("错误", isPresented: .constant(error != nil)) {
                Button("好") { error = nil }
            } message: { Text(error ?? "") }
            .confirmationDialog("删除这张卡密？", isPresented: .constant(confirmDelete != nil)) {
                Button("删除", role: .destructive) {
                    if let lic = confirmDelete { act(lic, op: "delete") }
                    confirmDelete = nil
                }
                Button("取消", role: .cancel) { confirmDelete = nil }
            }
        }
    }

    private func reload() async {
        loading = true
        do { list = try await api.licenses() }
        catch { self.error = error.localizedDescription }
        loading = false
    }

    private func act(_ lic: License, op: String) {
        Task {
            do {
                try await api.licenseAction(id: lic.id, op: op)
                await reload()
            } catch { self.error = error.localizedDescription }
        }
    }

    private func dateStr(_ t: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(t)))
    }
}
