import SwiftUI

/// 设备显示格式：多模板管理（切换/新增/编辑/删除）
struct DeviceDisplaySettingsView: View {
    @ObservedObject var store: DeviceTemplateStore
    @Environment(\.dismiss) var dismiss
    @State private var newName = ""
    @State private var newCompact = false
    @State private var showAdd = false
    @State private var editing: DeviceDisplayTemplate?

    var body: some View {
        NavigationView {
            List {
                Section("当前使用") {
                    ForEach(store.templates) { t in
                        HStack {
                            Button {
                                store.activate(t)
                            } label: {
                                HStack {
                                    Image(systemName: store.activeId == t.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(store.activeId == t.id ? .blue : .gray)
                                    VStack(alignment: .leading) {
                                        Text(t.name)
                                            .foregroundColor(.primary)
                                        Text("\(t.compact ? "紧凑" : "详细") · \(t.fields.count) 个字段")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button("编辑") { editing = t }
                                .font(.subheadline)
                        }
                    }
                }

                Section {
                    Button {
                        showAdd = true
                    } label: {
                        Label("新增显示格式", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("显示格式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showAdd) {
                NavigationView {
                    Form {
                        Section("名称") {
                            TextField("例如：只看设备码", text: $newName)
                        }
                        Section("卡片样式") {
                            Picker("样式", selection: $newCompact) {
                                Text("详细卡片").tag(false)
                                Text("紧凑单行").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                        Section(footer: Text("创建后可在编辑里调整字段和顺序。")) {
                            Button("创建") {
                                let name = newName.trimmingCharacters(in: .whitespaces)
                                store.add(name: name.isEmpty ? "未命名" : name,
                                          compact: newCompact,
                                          fields: DeviceDisplayField.allCases)
                                newName = ""
                                newCompact = false
                                showAdd = false
                            }
                        }
                    }
                    .navigationTitle("新增格式")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") { showAdd = false }
                        }
                    }
                }
            }
            .sheet(item: $editing) { t in
                NavigationView {
                    DeviceTemplateEditorView(store: store, template: t)
                }
            }
        }
    }
}
