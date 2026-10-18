import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var api: AdminAPI
    @State private var server = ""
    @State private var saved = false

    var body: some View {
        NavigationView {
            Form {
                Section("服务器") {
                    TextField("https://…/luiyo", text: $server)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("保存") {
                        api.saveServer(server)
                        saved = true
                    }
                    if saved {
                        Text("已保存，下次登录生效").font(.footnote).foregroundColor(.green)
                    }
                }
                Section {
                    Button("退出登录", role: .destructive) {
                        api.logout()
                    }
                }
                Section("关于") {
                    HStack { Text("应用"); Spacer(); Text("LUIYo后台 1.0.0") }
                    HStack { Text("构建"); Spacer(); Text("0") }
                }
            }
            .navigationTitle("设置")
            .onAppear { server = api.serverBase; saved = false }
        }
    }
}
