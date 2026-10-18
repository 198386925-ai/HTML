import SwiftUI

/// 单个显示模板的编辑器：改名、选样式、字段开关+排序
struct DeviceTemplateEditorView: View {
    @ObservedObject var store: DeviceTemplateStore
    @State var template: DeviceDisplayTemplate
    @Environment(\.dismiss) var dismiss

    var hiddenFields: [DeviceDisplayField] {
        DeviceDisplayField.allCases.filter { !template.fields.contains($0) }
    }

    var body: some View {
        Form {
            Section("名称") {
                TextField("模板名称", text: $template.name)
            }

            Section("卡片样式") {
                Picker("样式", selection: $template.compact) {
                    Text("详细卡片").tag(false)
                    Text("紧凑单行").tag(true)
                }
                .pickerStyle(.segmented)
            }

            Section(footer: Text("字体大小与布局疏密为全局设置，在「设置」中调整。")) {
                EmptyView()
            }

            Section(header: Text("显示字段（按住拖动排序）")) {
                ForEach(template.fields, id: \.self) { field in
                    HStack {
                        Text(field.title)
                        Spacer()
                        Button {
                            template.fields.removeAll(where: { $0 == field })
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onMove { from, to in
                    template.fields.move(fromOffsets: from, toOffset: to)
                }
            }

            if !hiddenFields.isEmpty {
                Section("已隐藏（点按加回）") {
                    ForEach(hiddenFields, id: \.self) { field in
                        Button {
                            template.fields.append(field)
                        } label: {
                            HStack {
                                Text(field.title).foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }

            Section {
                Button("删除此模板", role: .destructive) {
                    store.delete(template)
                    dismiss()
                }
                .disabled(store.templates.count <= 1)
            }
        }
        .navigationTitle("编辑模板")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    if template.name.trimmingCharacters(in: .whitespaces).isEmpty {
                        template.name = "未命名"
                    }
                    store.update(template)
                    dismiss()
                }
            }
        }
    }
}
