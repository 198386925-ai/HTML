import SwiftUI

/// 总览首页：简洁白卡风格（用户确认版）
/// 4 统计卡片 + 设备状态 + 4 快捷入口
struct OverviewView: View {
    @EnvironmentObject var display: AppDisplaySettings
    @EnvironmentObject var api: AdminAPI
    @Binding var tab: AdminTab
    @State private var stats: Stats?
    @State private var error: String?
    @State private var showSettings = false

    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // 顶部标题
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
                                .frame(width: 40, height: 40)
                                .background(Color(.systemBackground))
                                .cornerRadius(20)
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)

                    if let s = stats {
                        // 4 统计卡片
                        LazyVGrid(columns: columns, spacing: 12) {
                            NewStatCard(title: "累计激活设备", value: "\(s.totalDevices)", icon: "iphone", color: .blue)
                            NewStatCard(title: "今日活跃", value: "\(s.activeToday)", icon: "bolt.fill", color: .green)
                            NewStatCard(title: "近7日活跃", value: "\(s.active7d)", icon: "chart.bar.fill", color: .orange)
                            NewStatCard(title: "已封禁设备", value: "\(s.banned)", icon: "nosign", color: .red)
                        }

                        // 设备状态
                        VStack(spacing: 0) {
                            NewStatusRow(label: "登记设备", value: "\(s.totalDevices)", color: .blue)
                            Divider().padding(.leading, 16)
                            NewStatusRow(label: "当前在线", value: "\(s.onlineNow)", color: .green)
                            Divider().padding(.leading, 16)
                            NewStatusRow(label: "未授权", value: "\(s.unauthorized)", color: .orange)
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)

                        // 快捷入口
                        VStack(spacing: 8) {
                            NewActionButton(icon: "plus.circle.fill", color: .blue, title: "生成卡密") { tab = .generate }
                            NewActionButton(icon: "iphone", color: .green, title: "设备管理") { tab = .devices }
                            NewActionButton(icon: "ticket.fill", color: .orange, title: "卡密管理") { tab = .codes }
                            NewActionButton(icon: "arrow.clockwise", color: .purple, title: "刷新数据") { Task { await load() } }
                        }
                    } else if let e = error {
                        Text(e).font(display.fBody).foregroundColor(.red)
                    } else {
                        ProgressView().padding()
                    }
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    var currentDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }

    func load() async {
        do {
            stats = try await api.stats()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct NewStatCard: View {
    @EnvironmentObject var display: AppDisplaySettings
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(display.fTitle3)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(color)
                .cornerRadius(18)
            Text(value)
                .font(display.fLargeTitle).bold()
            Text(title)
                .font(display.fCaption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct NewStatusRow: View {
    @EnvironmentObject var display: AppDisplaySettings
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label).font(display.fBody)
            Spacer()
            Text(value).font(display.fTitle).bold().foregroundColor(color)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

struct NewActionButton: View {
    @EnvironmentObject var display: AppDisplaySettings
    let icon: String
    let color: Color
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(display.fTitle3)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(color)
                    .cornerRadius(18)
                Text(title).font(display.fBody)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(display.fCaption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
