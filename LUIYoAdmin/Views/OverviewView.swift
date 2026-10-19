import SwiftUI

/// 总览首页：现代仪表盘风格
/// 统计卡片（4项）+ 设备状态（3项）+ 快捷入口（4个）
struct OverviewView: View {
    @EnvironmentObject var display: AppDisplaySettings
    @EnvironmentObject var api: AdminAPI
    @Binding var tab: AdminTab
    @State private var stats: Stats?
    @State private var error: String?
    @State private var showSettings = false

    let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 10) {
                    // 顶部标题区
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LUIYo 后台")
                                .font(display.fTitle2).bold()
                            Text(currentDateString)
                                .font(display.fSubheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(display.fTitle3)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .nativeCapsuleGlass()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 2)

                    // 统计卡片
                    if let s = stats {
                        LazyVGrid(columns: columns, spacing: 8) {
                            DashboardStatCard(
                                title: "累计激活设备",
                                value: "\(s.totalDevices)",
                                icon: "iphone",
                                color: .blue
                            )
                            DashboardStatCard(
                                title: "今日活跃",
                                value: "\(s.activeToday)",
                                icon: "bolt.fill",
                                color: .green
                            )
                            DashboardStatCard(
                                title: "近7日活跃",
                                value: "\(s.activeWeek)",
                                icon: "chart.bar.fill",
                                color: .orange
                            )
                            DashboardStatCard(
                                title: "已封禁设备",
                                value: "\(s.banned)",
                                icon: "nosign",
                                color: .red
                            )
                        }

                        // 设备状态条
                        VStack(spacing: 0) {
                            HStack {
                                Text("设备状态")
                                    .font(display.fHeadline)
                                Spacer()
                                Button("查看全部 ›") { tab = .devices }
                                    .font(display.fSubheadline)
                                    .foregroundColor(.blue)
                            }
                            .padding(.bottom, 8)

                            HStack(spacing: 8) {
                                DeviceStatusPill(
                                    title: "登记设备",
                                    value: "\(s.totalDevices)",
                                    color: .blue
                                )
                                DeviceStatusPill(
                                    title: "当前在线",
                                    value: "\(s.online)",
                                    color: .green
                                )
                                DeviceStatusPill(
                                    title: "未授权",
                                    value: "\(s.unlicensed)",
                                    color: .orange
                                )
                            }
                        }
                        .padding(10)
                        .background(Color(.systemBackground)).cornerRadius(24).shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 160)
                    }

                    // 快捷入口
                    VStack(alignment: .leading, spacing: 8) {
                        Text("快捷入口")
                            .font(display.fHeadline)
                            .padding(.horizontal, 2)

                        LazyVGrid(columns: columns, spacing: 8) {
                            QuickActionCard(title: "生成卡密", icon: "plus.circle.fill", color: .blue) {
                                tab = .codes
                            }
                            QuickActionCard(title: "设备管理", icon: "iphone.circle.fill", color: .green) {
                                tab = .devices
                            }
                            QuickActionCard(title: "卡密管理", icon: "ticket.fill", color: .orange) {
                                tab = .licenses
                            }
                            QuickActionCard(title: "刷新数据", icon: "arrow.clockwise.circle.fill", color: .purple) {
                                load()
                            }
                        }
                    }

                    if let e = error {
                        Text(e)
                            .foregroundColor(.red)
                            .font(display.fFootnote)
                            .padding(8)
                    }
                }
                .padding(10)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .refreshable { load() }
            .onAppear { if stats == nil { load() } }
        }
    }

    private var currentDateString: String {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: Date())
    }

    private func load() {
        error = nil
        Task {
            do {
                stats = try await api.dashboard()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

/// 仪表盘统计卡片
struct DashboardStatCard: View {
    @EnvironmentObject var display: AppDisplaySettings
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(display.fBody)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(color)
                    .clipShape(Circle())
                Spacer()
            }
            Text(value)
                .font(.system(size: 22, weight: .bold))
            Text(title)
                .font(display.fSubheadline)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground)).cornerRadius(24).shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

/// 设备状态小胶囊
struct DeviceStatusPill: View {
    @EnvironmentObject var display: AppDisplaySettings
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(display.fTitle3).bold()
                .foregroundColor(color)
            Text(title)
                .font(display.fCaption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemBackground)).cornerRadius(20).shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

/// 快捷入口卡片
struct QuickActionCard: View {
    @EnvironmentObject var display: AppDisplaySettings
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(display.fTitle2)
                    .foregroundColor(color)
                Text(title)
                    .font(display.fHeadline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(display.fCaption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground)).cornerRadius(24).shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// 保留旧组件（其他页面仍在使用）
struct StatCell: View {
    @EnvironmentObject var display: AppDisplaySettings
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(display.fCaption).foregroundColor(.secondary)
            Text(value).font(display.fTitle2).bold()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct MiniStat: View {
    @EnvironmentObject var display: AppDisplaySettings
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(display.fCaption2).foregroundColor(.secondary)
            Text(value).font(display.fHeadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct ShortcutButton: View {
    @EnvironmentObject var display: AppDisplaySettings
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
