import SwiftUI

/// 生成激活码：与网页 codes 面板一致
/// 备注 / 设备数上限 / 有效天数（0为永久） / 生成数量 + 批量生成 + 近期生成记录
struct CodesView: View {
    @EnvironmentObject var display: AppDisplaySettings
    @EnvironmentObject var api: AdminAPI
    @State private var label = ""
    @State private var quantity = "1"
    @State private var maxDevices = "1"
    @State private var days = "0"
    @State private var busy = false
    @State private var error: String?
    @State private var history: [GeneratedBatch] = []
    @State private var selected: Set<UUID> = []
    @State private var selectedCodes: Set<String> = []

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("每次可生成 1–100 个，0 天表示永久。新卡密只在当前设备保留近期记录，请及时复制备份。")
                        .font(display.fCaption).foregroundColor(.secondary)
                        .listRowSeparator(.hidden)
                }

                Section("生成激活码") {
                    LabeledField(label: "备注", placeholder: "例如：张三", text: $label)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                        .padding(.top, 6)
                    LabeledField(label: "设备数上限", placeholder: "1", text: $maxDevices)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                        .keyboardType(.numberPad)
                    LabeledField(label: "有效天数", hint: "0 为永久", placeholder: "0", text: $days)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                        .keyboardType(.numberPad)
                    LabeledField(label: "生成数量", placeholder: "1", text: $quantity)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
                        .keyboardType(.numberPad)
                    Button(busy ? "生成中…" : "批量生成卡密") { generate() }
                        .disabled(busy)
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                    if let e = error {
                        Text(e).foregroundColor(.red).font(display.fFootnote)
                            .listRowSeparator(.hidden)
                    }
                }

                if !history.isEmpty {
                    Section {
                        HStack {
                            Text("近期生成记录").font(display.fHeadline)
                            Spacer()
                            Button(selected.count == history.count ? "取消全选" : "全选") {
                                selected = selected.count == history.count ? [] : Set(history.map(\.id))
                            }
                            .font(display.fSubheadline)
                            Button("批量复制") { copySelected() }
                                .font(display.fSubheadline)
                                .disabled(selected.isEmpty)
                        }
                        .listRowSeparator(.hidden)
                    }
                    ForEach(history) { batch in
                        Section {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dateStr(batch.date)).font(display.fSubheadline).bold()
                                    Text("设备上限 \(batch.maxDevices) · \(batch.days == 0 ? "永久" : "\(batch.days) 天") · \(batch.codes.count) 条")
                                        .font(display.fCaption).foregroundColor(.secondary)
                                    if !batch.label.isEmpty {
                                        Text(batch.label).font(display.fCaption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    if let idx = history.firstIndex(where: { $0.id == batch.id }) {
                                        history.remove(at: idx)
                                        selected.remove(batch.id)
                                        saveHistory()
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(display.fSubheadline)
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                Button {
                                    if selected.contains(batch.id) { selected.remove(batch.id) }
                                    else { selected.insert(batch.id) }
                                } label: {
                                    Image(systemName: selected.contains(batch.id)
                                        ? "checkmark.circle.fill" : "circle")
                                }
                                .buttonStyle(.plain)
                            }
                            .listRowSeparator(.hidden)
                            ForEach(batch.codes, id: \.self) { c in
                                HStack(spacing: 8) {
                                    Button {
                                        if selectedCodes.contains(c) { selectedCodes.remove(c) }
                                        else { selectedCodes.insert(c) }
                                    } label: {
                                        Image(systemName: selectedCodes.contains(c)
                                            ? "checkmark.square.fill" : "square")
                                    }
                                    .buttonStyle(.plain)
                                    Text(c).font(.system(.caption)).textSelection(.enabled)
                                    Spacer()
                                    Button { UIPasteboard.general.string = c } label: {
                                        Image(systemName: "doc.on.doc").font(display.fCaption)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .onDelete { idx in
                        history.remove(atOffsets: idx)
                        saveHistory()
                    }
                    Section {
                        Text("安全提示：旧卡密数据库只保存不可逆哈希，无法恢复明文。近期记录保存在本机，请及时复制到安全位置。")
                            .font(display.fCaption).foregroundColor(.secondary)
                            .listRowSeparator(.hidden)
                    }
                } else {
                    Section("近期生成记录") {
                        Text("暂时没有生成的卡密。").font(display.fFootnote).foregroundColor(.secondary)
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("生成")
            .onAppear(perform: loadHistory)
        }
    }

    private func generate() {
        busy = true
        error = nil
        Task {
            do {
                let md = max(1, min(100, Int(maxDevices) ?? 1))
                let d = max(0, min(3650, Int(days) ?? 0))
                let q = max(1, min(100, Int(quantity) ?? 1))
                let codes = try await api.createLicense(
                    label: label, maxDevices: md, days: d, quantity: q)
                let batch = GeneratedBatch(label: label, maxDevices: md,
                                           days: d, codes: codes)
                history.insert(batch, at: 0)
                history = Array(history.prefix(20))
                saveHistory()
                label = ""
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }

    private func copySelected() {
        var codes: [String] = []
        for b in history where selected.contains(b.id) { codes += b.codes }
        codes += selectedCodes
        UIPasteboard.general.string = Array(Set(codes)).joined(separator: "\n")
    }

    private func dateStr(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: d)
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "genHistory"),
           let h = try? JSONDecoder().decode([GeneratedBatch].self, from: data) {
            history = h
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "genHistory")
        }
    }
}

struct LabeledField: View {
    @EnvironmentObject var display: AppDisplaySettings
    let label: String
    var hint: String? = nil
    let placeholder: String
    @Binding var text: String
    var kbType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Text(label).font(display.fSubheadline)
                if let h = hint {
                    Text(h).font(display.fCaption).foregroundColor(.secondary)
                }
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .keyboardType(kbType)
        }
    }

    func keyboardType(_ t: UIKeyboardType) -> LabeledField {
        var v = self
        v.kbType = t
        return v
    }
}
