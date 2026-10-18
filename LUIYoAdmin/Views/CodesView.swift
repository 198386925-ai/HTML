import SwiftUI

/// 生成激活码：与网页 codes 面板一致（表单 + 近期生成记录 + 批量复制）
struct CodesView: View {
    @EnvironmentObject var api: AdminAPI
    @State private var label = ""
    @State private var quantity = "10"
    @State private var maxDevices = "1"
    @State private var days = "0"
    @State private var busy = false
    @State private var error: String?
    @State private var history: [GeneratedBatch] = []
    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationView {
            List {
                Section("生成激活码") {
                    TextField("备注", text: $label)
                    TextField("数量 1–100", text: $quantity).keyboardType(.numberPad)
                    TextField("每码设备数 1–100", text: $maxDevices).keyboardType(.numberPad)
                    TextField("有效天数（0=永久）", text: $days).keyboardType(.numberPad)
                    Button(busy ? "生成中…" : "生成") { generate() }
                        .disabled(busy)
                    if let e = error {
                        Text(e).foregroundColor(.red).font(.footnote)
                    }
                }

                if !history.isEmpty {
                    Section {
                        HStack {
                            Text("近期生成记录").font(.headline)
                            Spacer()
                            Button(selected.count == history.count ? "取消全选" : "全选") {
                                selected = selected.count == history.count ? [] : Set(history.map(\.id))
                            }
                            .font(.subheadline)
                            Button("批量复制") { copySelected() }
                                .font(.subheadline)
                                .disabled(selected.isEmpty)
                        }
                    }
                    ForEach(history) { batch in
                        Section {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(batch.label.isEmpty ? "无备注" : batch.label)
                                        .font(.subheadline).bold()
                                    Text("\(batch.codes.count) 个 · " + dateStr(batch.date))
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    if selected.contains(batch.id) { selected.remove(batch.id) }
                                    else { selected.insert(batch.id) }
                                } label: {
                                    Image(systemName: selected.contains(batch.id)
                                        ? "checkmark.circle.fill" : "circle")
                                }
                            }
                            ForEach(batch.codes, id: \.self) { c in
                                HStack {
                                    Text(c).font(.caption).monospace().textSelection(.enabled)
                                    Spacer()
                                    Button { UIPasteboard.general.string = c } label: {
                                        Image(systemName: "doc.on.doc").font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete { idx in
                        history.remove(atOffsets: idx)
                        saveHistory()
                    }
                }
            }
            .navigationTitle("生成")
            .onAppear(perform: loadHistory)
        }
    }

    private func generate() {
        busy = true
        error = nil
        Task {
            do {
                let codes = try await api.createLicense(
                    label: label,
                    maxDevices: max(1, min(100, Int(maxDevices) ?? 1)),
                    days: max(0, Int(days) ?? 0),
                    quantity: max(1, min(100, Int(quantity) ?? 1)))
                let batch = GeneratedBatch(label: label, quantity: codes.count, codes: codes)
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
        let codes = history.filter { selected.contains($0.id) }.flatMap(\.codes)
        UIPasteboard.general.string = codes.joined(separator: "\n")
    }

    private func dateStr(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
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
