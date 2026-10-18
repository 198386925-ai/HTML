import SwiftUI

/// 总览首页：现代仪表盘风格
/// 统计卡片（4项）+ 设备状态（3项）+ 快捷入口（4个）
struct OverviewView: View {
    @EnvironmentObject var api: AdminAPI
    @Binding var tab: AdminTab
    @State private var stats: Stats?
    @State private var error: String?
    @State private var showSettings = false

    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 顶部标题区
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LUIYo 后台")
                                .font(.title2).bold()
                            Text(currentDateString)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .padding(10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 4)

                    // 统计卡片
                    if let s = stats {
                        LazyVGrid(columns: columns, spacing: 12) {
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
                                    .font(.headline)
                                Spacer()
                                Button("查看全部 ›") { tab = .devices }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            .padding(.bottom, 12)

                            HStack(spacing: 12) {
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
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    }

                    // 快捷入口
                    VStack(alignment: .leading, spacing: 12) {
                        Text("快捷入口")
                            .font(.headline)
                            .padding(.horizontal, 4)

                        LazyVGrid(columns: columns, spacing: 12) {
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
                            .font(.footnote)
                            .padding()
                    }
                }
                .padding()
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
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(color)
                    .clipShape(Circle())
                Spacer()
            }
            Text(value)
                .font(.system(size: 24, weight: .bold))
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

/// 设备状态小胶囊
struct DeviceStatusPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3).bold()
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

/// 快捷入口卡片
struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// 保留旧组件（其他页面仍在使用）
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
