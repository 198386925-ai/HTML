import SwiftUI

/// 5 个面板与网页后台完全一致：总览 / 生成 / 设备 / 卡密 / 版本
enum AdminTab: Int {
    case overview, codes, devices, licenses, versions
}

struct ContentView: View {
    @EnvironmentObject var api: AdminAPI
    @EnvironmentObject var display: AppDisplaySettings
    @State private var tab: AdminTab = .overview

    var body: some View {
        Group {
            if api.loggedIn {
                TabView(selection: $tab) {
                    OverviewView(tab: $tab)
                        .tabItem { Label("总览", image: "TabOverview") }
                        .tag(AdminTab.overview)
                    CodesView()
                        .tabItem { Label("生成", image: "TabGenerate") }
                        .tag(AdminTab.codes)
                    DevicesView()
                        .tabItem { Label("设备", image: "TabDevices") }
                        .tag(AdminTab.devices)
                    LicensesView()
                        .tabItem { Label("卡密", image: "TabLicenses") }
                        .tag(AdminTab.licenses)
                    VersionsView()
                        .tabItem { Label("版本", image: "TabVersions") }
                        .tag(AdminTab.versions)
                }
                // 全局字号
                .environment(\.sizeCategory, display.sizeCategory)
            } else {
                LoginView()
            }
        }
        // 全局自定义字体（未设置时不覆盖）
        .environment(\.font, display.defaultFont)
    }
}
