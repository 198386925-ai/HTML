import SwiftUI

/// 6 个面板：总览 / 生成 / 设备 / 卡密 / 版本 / 账号（邮箱账号新系统）
enum AdminTab: Int {
    case overview, codes, devices, licenses, versions, accounts
}

struct ContentView: View {
    @EnvironmentObject var api: AdminAPI
    @EnvironmentObject var display: AppDisplaySettings
    @State private var tab: AdminTab = .overview
    @State private var autoLoginAttempted = false

    var body: some View {
        Group {
            if api.loggedIn {
                TabView(selection: $tab) {
                    OverviewView(tab: $tab)
                        .tabItem {
                            Image("TabOverview")
                            Text("总览")
                        }
                        .tag(AdminTab.overview)
                    CodesView()
                        .tabItem {
                            Image("TabGenerate")
                            Text("生成")
                        }
                        .tag(AdminTab.codes)
                    DevicesView()
                        .tabItem {
                            Image("TabDevices")
                            Text("设备")
                        }
                        .tag(AdminTab.devices)
                    LicensesView()
                        .tabItem {
                            Image("TabLicenses")
                            Text("卡密")
                        }
                        .tag(AdminTab.licenses)
                    VersionsView()
                        .tabItem {
                            Image("TabVersions")
                            Text("版本")
                        }
                        .tag(AdminTab.versions)
                    AccountsView()
                        .tabItem {
                            Image("TabAccounts")
                            Text("账号")
                        }
                        .tag(AdminTab.accounts)
                }
            } else if autoLoginAttempted {
                // 自动登录中，显示 loading（比登录页闪一下更快）
                ProgressView("登录中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LoginView()
            }
        }
        .environment(\.font, display.defaultFont)
        .onAppear {
            // 自动登录：有保存的密码则直接登录，不显示登录页
            if !api.loggedIn && !autoLoginAttempted {
                autoLoginAttempted = true
                if let saved = Keychain.load(), !saved.isEmpty {
                    Task {
                        try? await api.login(password: saved)
                        // 登录失败则回到登录页
                        if !api.loggedIn {
                            autoLoginAttempted = false
                        }
                    }
                } else {
                    autoLoginAttempted = false
                }
            }
        }
    }
}
