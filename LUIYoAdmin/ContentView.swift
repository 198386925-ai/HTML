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
                        .tabItem {
                            Image(systemName: "chart.bar")
                            Text("总览")
                        }
                        .tag(AdminTab.overview)
                    CodesView()
                        .tabItem {
                            Image(systemName: "plus.app")
                            Text("生成")
                        }
                        .tag(AdminTab.codes)
                    DevicesView()
                        .tabItem {
                            Image(systemName: "iphone")
                            Text("设备")
                        }
                        .tag(AdminTab.devices)
                    LicensesView()
                        .tabItem {
                            Image(systemName: "ticket")
                            Text("卡密")
                        }
                        .tag(AdminTab.licenses)
                    VersionsView()
                        .tabItem {
                            Image(systemName: "tag")
                            Text("版本")
                        }
                        .tag(AdminTab.versions)
                }
            } else {
                LoginView()
            }
        }
    }
}
