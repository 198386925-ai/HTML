import SwiftUI

/// 设备显示格式自定义：卡片样式 + 各字段开关
struct DeviceDisplaySettingsView: View {
    @Binding var prefs: DeviceDisplayPrefs
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("卡片样式") {
                    Picker("样式", selection: $prefs.compact) {
                        Text("详细").tag(false)
                        Text("紧凑").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Text(prefs.compact ? "每台设备只显示一行" : "显示完整信息卡片")
                        .font(.caption).foregroundColor(.secondary)
                }

                Section("显示字段") {
                    Toggle("设备码", isOn: $prefs.showDeviceCode)
                    Toggle("卡密信息", isOn: $prefs.showLicense)
                    Toggle("状态", isOn: $prefs.showStatus)
                    Toggle("在线状态", isOn: $prefs.showOnline)
                    Toggle("当前页面", isOn: $prefs.showPage)
                    Toggle("设备信息（机型/系统/版本）", isOn: $prefs.showMeta)
                    Toggle("活跃时间", isOn: $prefs.showLastSeen)
                    Toggle("首次登记/安装记录", isOn: $prefs.showCreated)
                    Toggle("操作按钮", isOn: $prefs.showActions)
                }

                Section {
                    Button("恢复默认") {
                        prefs = DeviceDisplayPrefs()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("显示格式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        prefs.save()
                        dismiss()
                    }
                }
            }
            .onChange(of: prefs) { _ in prefs.save() }
        }
    }
}
