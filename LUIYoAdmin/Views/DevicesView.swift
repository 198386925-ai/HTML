import SwiftUI

/// 设备与在线用户：与网页 devices 面板一致
/// 设备码授权 + 3项统计 + 筛选/搜索 + 设备表（封禁/解封/授权/撤销）
struct DevicesView: View {
    @EnvironmentObject var api: AdminAPI
    @State private var list: [DeviceInfo] = []
    @State private var loading = false
    @State private var error: String?
    @State private var query = ""
    @State private var filter = "all"
    @State private var grantCode = ""
    @State private var grantBusy = false
    @State private var banTarget: DeviceInfo?
    @State private var banReason = ""
    @State private var confirmOp: (DeviceInfo, String)?

    let filters = [("all", "全部设备"), ("online", "在线设备"),
                   ("licensed", "已授权"), ("unlicensed", "未授权")]

    var filtered: [DeviceInfo] {
        var r = list
        switch filter {
        case "online": r = r.filter(\.online)
        case "licensed": r = r.filter { $0.status != "未授权" }
        case "unlicensed": r = r.filter { $0.status == "未授权" }
        default: break
        }
        guard !query.isEmpty else { return r }
        let q = query.lowercased()
        return r.filter {
            $0.deviceCode.lowercased().contains(q)
            || ($0.model ?? "").lowercased().contains(q)
            || ($0.label ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationView {
            List {
                // 设备码授权
                Section("设备码授权") {
                    TextField("D-000001", text: $grantCode)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                    HStack {
                        Button(grantBusy ? "处理中…" : "授权 SVIP 3") {
                            grantOp(op: "grant")
                        }
                        .disabled(grantBusy || grantCode.isEmpty)
                        Button("撤销", role: .destructive) {
                            grantOp(op: "revoke")
                        }
                        .disabled(grantBusy || grantCode.isEmpty)
                    }
                    Text("输入已登记设备的完整编号；新版 App 联网后自动领取，不会覆盖已有卡密授权。")
                        .font(.caption).foregroundColor(.secondary)
                }

                // 3项统计
                Section("设备与在线用户") {
                    HStack(spacing: 10) {
                        MiniStat(title: "新版登记设备", value: "\(list.count)")
                        MiniStat(title: "当前在线", value: "\(list.filter(\.online).count)")
                        MiniStat(title: "未授权设备", value: "\(list.filter { $0.status == "未授权" }.count)")
                    }
                    Picker("筛选", selection: $filter) {
                        ForEach(filters, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .pickerStyle(.segmented)
                }

                // 设备表
                Section("设备列表（\(filtered.count)）") {
                    ForEach(filtered) { d in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(d.deviceCode).font(.system(.headline, design: .monospaced))
                                if d.online {
                                    Circle().fill(Color.green).frame(width: 8, height: 8)
                                }
                                Spacer()
                                Text(d.status).font(.caption)
                                    .foregroundColor(statusColor(d.status))
                            }
                            HStack {
                                Text([d.model, d.osVersion].compactMap { $0 }.joined(separator: " "))
                                Spacer()
                                if let p = d.page, !p.isEmpty { Text(p) }
                            }
                            .font(.caption).foregroundColor(.secondary)
                            HStack {
                                if let l = d.label, !l.isEmpty { Text("授权：" + l) }
                                Spacer()
                                Text("活跃 " + d.lastSeenText)
                            }
                            .font(.caption).foregroundColor(.secondary)
                        }
                        .swipeActions(edge: .trailing) {
                            if d.banned {
                                Button("解封") { confirmOp = (d, "unban") }.tint(.green)
                            } else {
                                Button("封禁") { banTarget = d; banReason = "" }.tint(.red)
                            }
                            Button("授权") { confirmOp = (d, "grant") }.tint(.blue)
                            Button("撤销", role: .destructive) { confirmOp = (d, "revoke") }
                        }
                    }
                }
            }
            .navigationTitle("设备")
            .searchable(text: $query, prompt: "搜索设备码/机型/备注")
            .refreshable { await reload() }
            .task { await reload() }
            .alert("错误", isPresented: .constant(error != nil)) {
                Button("好") { error = nil }
            } message: { Text(error ?? "") }
            .alert("封禁设备", isPresented: .constant(banTarget != nil)) {
                TextField("封禁原因（可选）", text: $banReason)
                Button("取消", role: .cancel) { banTarget = nil }
                Button("封禁", role: .destructive) {
                    if let d = banTarget { act(d, op: "ban", reason: banReason) }
                    banTarget = nil
                }
            }
            .confirmationDialog("确认操作", isPresented: .constant(confirmOp != nil)) {
                Button(opTitle, role: opDestructive ? .destructive : .none) {
                    if let (d, op) = confirmOp { act(d, op: op) }
                    confirmOp = nil
                }
                Button("取消", role: .cancel) { confirmOp = nil }
            } message: {
                if let (d, _) = confirmOp { Text("\(opTitle)：\(d.deviceCode)") }
            }
        }
    }

    private var opTitle: String {
        switch confirmOp?.1 {
        case "unban": return "解封设备"
        case "grant": return "授权设备"
        case "revoke": return "撤销授权"
        default: return "操作"
        }
    }
    private var opDestructive: Bool { confirmOp?.1 == "revoke" }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "已授权": return .green
        case "已封禁": return .red
        case "未授权": return .orange
        default: return .secondary
        }
    }

    private func grantOp(op: String) {
        grantBusy = true
        Task {
            do {
                try await api.deviceAction(id: 0, deviceCode: grantCode.uppercased(),
                                           op: op)
                grantCode = ""
                await reload()
            } catch { self.error = error.localizedDescription }
            grantBusy = false
        }
    }

    private func reload() async {
        loading = true
        do { list = try await api.devices() }
        catch { self.error = error.localizedDescription }
        loading = false
    }

    private func act(_ d: DeviceInfo, op: String, reason: String = "") {
        Task {
            do {
                try await api.deviceAction(id: d.id, deviceCode: d.deviceCode,
                                           op: op, reason: reason)
                await reload()
            } catch { self.error = error.localizedDescription }
        }
    }
}
