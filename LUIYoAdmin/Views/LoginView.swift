import SwiftUI

struct LoginView: View {
    @EnvironmentObject var display: AppDisplaySettings
    @EnvironmentObject var api: AdminAPI
    @State private var server = UserDefaults.standard.string(forKey: "serverBase")
        ?? "https://mistoto.cc.cd/luiyo"
    @State private var password = Keychain.load() ?? ""
    @State private var remember = Keychain.load() != nil
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationView {
            Form {
                Section("服务器") {
                    TextField("https://…/luiyo", text: $server)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                Section("管理员密码") {
                    SecureField("密码", text: $password)
                    Toggle("记住密码", isOn: $remember)
                }
                if let e = error {
                    Section { Text(e).foregroundColor(.red).font(display.fFootnote) }
                }
                Section {
                    Button(busy ? "登录中…" : "登录") { login() }
                        .disabled(busy || password.isEmpty)
                }
            }
            .navigationTitle("LUIYo 后台管理")
        }
    }

    private func login() {
        busy = true
        error = nil
        api.saveServer(server)
        Task {
            do {
                try await api.login(password: password)
                if remember { Keychain.save(password) } else { Keychain.delete() }
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}
