import SwiftUI

/// 5 个面板与网页后台完全一致：总览 / 生成 / 设备 / 卡密 / 版本
enum AdminTab: Int {
    case overview, codes, devices, licenses, versions
}

struct ContentView: View {
    @EnvironmentObject var api: AdminAPI
    @State private var tab: AdminTab = .overview

    var body: some View {
        Group {
            if api.loggedIn {
                TabView(selection: $tab) {
                    OverviewView(tab: $tab)
                        .tabItem { Label("总览", systemImage: "chart.bar") }
                        .tag(AdminTab.overview)
                    CodesView()
                        .tabItem { Label("生成", systemImage: "plus.app") }
                        .tag(AdminTab.codes)
                    DevicesView()
                        .tabItem { Label("设备", systemImage: "iphone") }
                        .tag(AdminTab.devices)
                    LicensesView()
                        .tabItem { Label("卡密", systemImage: "ticket") }
                        .tag(AdminTab.licenses)
                    VersionsView()
                        .tabItem { Label("版本", systemImage: "tag") }
                        .tag(AdminTab.versions)
                }
            } else {
                LoginView()
            }
        }
    }
}
