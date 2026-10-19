import SwiftUI

/// 设备与在线用户：与网页 devices 面板完全一致
/// 设备码授权 + 3项统计 + 筛选/搜索/刷新 + 设备卡片（取消授权·添加授权·修改设备）
/// + 原有授权设备管理（封禁/解封）
struct DevicesView: View {
    @EnvironmentObject var api: AdminAPI
    @EnvironmentObject var display: AppDisplaySettings
    @State private var list: [DeviceInfo] = []
    @State private var installationTotal = 0
    @State private var loading = false
    @State private var error: String?
    @State private var query = ""
    @State private var filter = "all"
    @State private var grantCode = ""
    @State private var grantBusy = false
    @State private var legacyList: [LegacyDevice] = []
    @State private var legacyBanTarget: LegacyDevice?
    @State private var banReason = ""
    @State private var modifyTarget: DeviceInfo?
    @State private var newCode = ""
    @State private var refreshTimer: Timer?
    @StateObject private var templateStore = DeviceTemplateStore()
    @State private var showDisplaySettings = false

    let filters = [("all", "全部设备"), ("online", "在线设备"),
                   ("licensed", "已授权"), ("unlicensed", "未授权")]

    var filtered: [DeviceInfo] {
        var r = list
        switch filter {
        case "online": r = r.filter(\.online)
        case "licensed": r = r.filter { $0.status == "已授权" }
        case "unlicensed": r = r.filter { $0.status == "未授权" }
        default: break
        }
        guard !query.isEmpty else { return r }
        let q = query.lowercased()
        return r.filter {
            $0.deviceCode.lowercased().contains(q)
            || ($0.label ?? "").lowercased().contains(q)
            || ($0.model ?? "").lowercased().contains(q)
        }
    }

    var legacyFiltered: [LegacyDevice] {
        guard !query.isEmpty else { return legacyList }
        let q = query.lowercased()
        return legacyList.filter {
            ($0.deviceCode ?? "").lowercased().contains(q)
            || $0.authMode.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationView {
            List {
                // 设备码授权
                Section("设备码授权") {
                    HStack(spacing: 8) {
                        TextField("D-000001", text: $grantCode)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .font(display.fBody)
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                        Button(grantBusy ? "处理中…" : "授权") {
                            grantOp(op: "grant")
                        }
                        .disabled(grantBusy || grantCode.isEmpty)
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }

                }

                // 设备与在线用户
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

                // 设备卡片列表
                Section(header: Text("显示 \(filtered.count) 台 · 设备 \(list.count) 台（安装记录 \(installationTotal) 条）")) {
                    ForEach(filtered) { d in
                        if templateStore.active.compact {
                            // 紧凑：一行
                            HStack {
                                if templateStore.active.has(.deviceCode) {
                                    Text(d.deviceCode)
                                        .font(.system(.subheadline))
                                        .fontWeight(.semibold)
                                }
                                if templateStore.active.has(.status) {
                                    Text(d.status).font(display.fCaption).foregroundColor(statusColor(d.status))
                                }
                                if templateStore.active.has(.license), let l = d.label, !l.isEmpty {
                                    Text(l).font(display.fCaption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if templateStore.active.has(.online) {
                                    Text(d.online ? "●" : "○").font(display.fCaption)
                                        .foregroundColor(d.online ? .green : .secondary)
                                }
                                if templateStore.active.has(.actions) {
                                    Menu {
                                        Button(d.status == "已授权" ? "取消授权" : "添加授权") {
                                            grantOp(op: d.status == "已授权" ? "revoke" : "grant", code: d.deviceCode)
                                        }
                                        Button("修改设备") {
                                            modifyTarget = d
                                            newCode = d.deviceCode
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle").foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, display.density.cardPadding)
                        } else {
                            // 详细：完整卡片
                            VStack(alignment: .leading, spacing: display.density.vSpacing) {
                                HStack {
                                    if templateStore.active.has(.deviceCode) {
                                        Text(d.deviceCode)
                                            .font(.system(.headline))
                                    }
                                    Spacer()
                                    if templateStore.active.has(.online) {
                                        Text(d.online ? "● 在线" : "离线")
                                            .font(display.fCaption)
                                            .foregroundColor(d.online ? .green : .secondary)
                                    }
                                    if templateStore.active.has(.page) {
                                        Text(d.pageName)
                                            .font(display.fCaption).foregroundColor(.secondary)
                                    }
                                }
                                if templateStore.active.has(.status) || templateStore.active.has(.license) {
                                    HStack {
                                        Text(statusText(for: d))
                                            .font(display.fCaption)
                                            .foregroundColor(statusColor(d.status))
                                        Spacer()
                                    }
                                }
                                if templateStore.active.has(.meta) && !d.metaText.isEmpty {
                                    Text(d.metaText)
                                        .font(display.fCaption).foregroundColor(.secondary)
                                }
                                if templateStore.active.has(.created) || templateStore.active.has(.actions) {
                                    HStack(alignment: .bottom) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            if templateStore.active.has(.lastSeen) {
                                                Text("活跃 " + d.lastSeenText)
                                                    .font(display.fCaption).foregroundColor(.secondary)
                                            }
                                            if templateStore.active.has(.created) {
                                                HStack {
                                                    Text("首次登记 " + d.createdAtText)
                                                    if d.installationCount > 1 {
                                                        Text("· 安装记录 " + d.installationCodes.joined(separator: "、"))
                                                    }
                                                }
                                                .font(display.fCaption2).foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if templateStore.active.has(.actions) {
                                            HStack(spacing: 8) {
                                                if d.status == "已授权" {
                                                    Button("取消授权") { grantOp(op: "revoke", code: d.deviceCode) }
                                                        .buttonStyle(.bordered)
                                                        .tint(.red)
                                                } else {
                                                    Button("添加授权") { grantOp(op: "grant", code: d.deviceCode) }
                                                        .buttonStyle(.borderedProminent)
                                                }
                                                Button("修改设备") {
                                                    modifyTarget = d
                                                    newCode = d.deviceCode
                                                }
                                                .buttonStyle(.bordered)
                                            }
                                            .font(display.fSubheadline)
                                        }
                                    }
                                }

                            }
                            .padding(.vertical, display.density.cardPadding)
                        }
                    }
                }
                .environment(\.sizeCategory, templateSizeCategory)

                // 原有授权设备管理（最近 200 条）
                Section("原有授权设备管理（\(legacyFiltered.count)）") {
                    ForEach(legacyFiltered) { d in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(d.deviceCode ?? "未登记设备（记录 #\(d.id)）")
                                    .font(.system(.headline))
                                Spacer()
                                Text(d.banned ? "已封禁" : "正常")
                                    .font(display.fCaption)
                                    .foregroundColor(d.banned ? .red : .green)
                            }
                            // 卡密授权：把卡密显示在设备码下面；设备码授权：第二行显示"设备码授权"
                            if d.authMode != "设备码授权",
                               let code = d.licenseCode, !code.isEmpty {
                                Text(code)
                                    .font(.system(.caption))
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                            HStack {
                                Text(d.authMode)
                                Spacer()
                                Text("活跃 " + d.lastSeenText)
                            }
                            .font(display.fCaption).foregroundColor(.secondary)
                        }
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            if d.banned {
                                Button("解封") { legacyAct(d, op: "unban") }.tint(.green)
                            } else {
                                Button("封禁") { legacyBanTarget = d; banReason = "" }.tint(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("设备")
            .searchable(text: $query, prompt: "搜索设备码或备注")
            .refreshable { await reload() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDisplaySettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showDisplaySettings) {
                DeviceDisplaySettingsView(store: templateStore)
            }
            .task {
                await reload()
                startAutoRefresh()
            }
            .onDisappear { stopAutoRefresh() }
            .alert("错误", isPresented: .constant(error != nil)) {
                Button("好") { error = nil }
            } message: { Text(error ?? "") }

            // 修改设备码
            .alert("修改设备码", isPresented: .constant(modifyTarget != nil)) {
                TextField("D-000002", text: $newCode)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                Button("取消", role: .cancel) { modifyTarget = nil }
                Button("保存") {
                    if let d = modifyTarget {
                        let code = newCode.trimmingCharacters(in: .whitespaces).uppercased()
                        if code != d.deviceCode {
                            modifyCode(d, newCode: code)
                        }
                    }
                    modifyTarget = nil
                }
            } message: {
                if let d = modifyTarget {
                    Text("修改设备 \(d.deviceCode) 的设备码：\n输入新的设备码（例如 D-000002）")
                }
            }
            // 封禁原因
            .alert("封禁设备", isPresented: .constant(legacyBanTarget != nil)) {
                TextField("封禁原因（可选）", text: $banReason)
                Button("取消", role: .cancel) { legacyBanTarget = nil }
                Button("封禁", role: .destructive) {
                    if let d = legacyBanTarget { legacyAct(d, op: "ban", reason: banReason) }
                    legacyBanTarget = nil
                }
            }
        }
    }

    /// 状态行文本：按显示偏好组合状态 + 卡密信息
    private func statusText(for d: DeviceInfo) -> String {
        var t = ""
        if templateStore.active.has(.status) { t += d.status }
        if templateStore.active.has(.license), let l = d.label, !l.isEmpty {
            t += (t.isEmpty ? "" : " · ") + l
        }
        return t
    }

    /// 模板字体大小 -> 系统字号
    private var templateSizeCategory: ContentSizeCategory {
        switch display.fontSize {
        case .small: return .small
        case .standard: return .medium
        case .large: return .large
        case .extraLarge: return .extraExtraLarge
        }
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "已授权": return .green
        case "已封禁": return .red
        case "未授权": return .orange
        case "已停用", "已过期": return .red
        default: return .secondary
        }
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { await reload() }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func grantOp(op: String, code: String? = nil) {
        let c = (code ?? grantCode).uppercased()
        guard !c.isEmpty else { return }
        grantBusy = true
        Task {
            do {
                try await api.deviceAction(id: 0, deviceCode: c, op: op)
                if code == nil { grantCode = "" }
                await reload()
            } catch { self.error = error.localizedDescription }
            grantBusy = false
        }
    }

    private func modifyCode(_ d: DeviceInfo, newCode: String) {
        guard newCode.range(of: "^D-[0-9]{6,9}$", options: .regularExpression) != nil else {
            self.error = "设备码格式错误，应为 D-加6到9位数字"
            return
        }
        Task {
            do {
                try await api.modifyDeviceCode(deviceCode: d.deviceCode, newCode: newCode)
                await reload()
            } catch { self.error = error.localizedDescription }
        }
    }

    private func reload() async {
        do {
            async let a = api.devices()
            async let b = api.legacyDevices()
            let snap = try await a
            list = snap
            legacyList = try await b
            // 安装记录总数
            installationTotal = snap.reduce(0) { $0 + $1.installationCount }
        } catch {
            // 自动刷新时不打断用户
            if list.isEmpty { self.error = error.localizedDescription }
        }
    }

    private func legacyAct(_ d: LegacyDevice, op: String, reason: String = "") {
        Task {
            do {
                try await api.legacyDeviceAction(legacyId: d.id, op: op, reason: reason)
                await reload()
            } catch { self.error = error.localizedDescription }
        }
    }
}
