import SwiftUI

/// 总览：与网页 overview 面板一致
/// 统计总览（4项）+ 设备与在线用户（3项+查看全部）+ 快捷导航（4个）
struct OverviewView: View {
    @EnvironmentObject var api: AdminAPI
    @Binding var tab: AdminTab
    @State private var stats: Stats?
    @State private var devices: [DeviceInfo] = []
    @State private var error: String?
    @State private var showSettings = false

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // 统计总览
                    GroupBox("统计总览") {
                        if let s = stats {
                            LazyVGrid(columns: columns, spacing: 10) {
                                StatCell(title: "累计激活设备", value: "\(s.totalDevices)")
                                StatCell(title: "今日活跃设备", value: "\(s.activeToday)")
                                StatCell(title: "近7日活跃设备", value: "\(s.activeWeek)")
                                StatCell(title: "已封禁设备", value: "\(s.banned)")
                            }
                        } else {
                            ProgressView().frame(maxWidth: .infinity)
                        }
                    }

                    // 设备与在线用户
                    GroupBox {
                        HStack {
                            Text("设备与在线用户").font(.headline)
                            Spacer()
                            Button("查看全部 ›") { tab = .devices }
                                .font(.subheadline)
                        }
                        if let s = stats {
                            HStack(spacing: 10) {
                                MiniStat(title: "新版登记设备", value: "\(s.totalDevices)")
                                MiniStat(title: "当前在线", value: "\(s.online)")
                                MiniStat(title: "未授权设备", value: "\(s.unlicensed)")
                            }
                        }
                    }

                    // 快捷导航
                    GroupBox("快捷导航") {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ShortcutButton(title: "生成卡密", icon: "plus") { tab = .codes }
                            ShortcutButton(title: "设备管理", icon: "iphone") { tab = .devices }
                            ShortcutButton(title: "卡密管理", icon: "ticket") { tab = .licenses }
                            ShortcutButton(title: "刷新", icon: "arrow.clockwise") { load() }
                        }
                    }

                    if let e = error {
                        Text(e).foregroundColor(.red).font(.footnote)
                    }
                }
                .padding()
            }
            .navigationTitle("总览")
            .toolbar {
                Button { showSettings = true } label: {
                    Image(systemName: "gear")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .refreshable { load() }
            .onAppear { if stats == nil { load() } }
        }
    }

    private func load() {
        error = nil
        Task {
            do {
                async let s = api.dashboard()
                async let d = api.devices()
                stats = try await s
                devices = try await d
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

struct StatCell: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title2).bold()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct MiniStat: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct ShortcutButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
