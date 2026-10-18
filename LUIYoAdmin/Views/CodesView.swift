import SwiftUI

/// 生成激活码：设计三风格（深紫底 + 白色圆卡）
struct CodesView: View {
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

    private let purple = Color(red: 0.29, green: 0.23, blue: 1.0)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("生成")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // 生成卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text("生成激活码")
                        .font(.headline)
                    Text("每次可生成 1–100 个，0 天表示永久。新卡密只在当前设备保留近期记录，请及时复制备份。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    PurpleField(label: "备注", placeholder: "例如：张三", text: $label)
                    PurpleField(label: "设备数上限", placeholder: "1", text: $maxDevices)
                    PurpleField(label: "有效天数", placeholder: "0 为永久", text: $days)
                    PurpleField(label: "生成数量", placeholder: "1", text: $quantity)

                    Button {
                        generate()
                    } label: {
                        Text(busy ? "生成中…" : "批量生成卡密")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(purple)
                            .cornerRadius(16)
                    }
                    .disabled(busy)
                    .opacity(busy ? 0.5 : 1.0)

                    if let e = error {
                        Text(e).foregroundColor(.red).font(.footnote)
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(24)
                .padding(.horizontal, 16)

                // 历史记录卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("近期生成记录")
                            .font(.headline)
                        Spacer()
                        if !history.isEmpty {
                            Button(selected.count == history.count ? "取消全选" : "全选") {
                                selected = selected.count == history.count ? [] : Set(history.map(\.id))
                            }
                            .font(.subheadline)
                            .foregroundColor(purple)
                            Button("批量复制") { copySelected() }
                                .font(.subheadline)
                                .foregroundColor(purple)
                                .disabled(selected.isEmpty)
                        }
                    }

                    if history.isEmpty {
                        Text("暂时没有生成的卡密。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(history) { batch in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(dateStr(batch.date))
                                            .font(.subheadline).bold()
                                        Text("设备上限 \(batch.maxDevices) · \(batch.days == 0 ? "永久" : "\(batch.days) 天") · \(batch.codes.count) 条")
                                            .font(.caption).foregroundColor(.secondary)
                                        if !batch.label.isEmpty {
                                            Text(batch.label)
                                                .font(.caption).foregroundColor(.secondary)
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
                                            .foregroundColor(.red)
                                    }
                                    Button {
                                        if selected.contains(batch.id) { selected.remove(batch.id) }
                                        else { selected.insert(batch.id) }
                                    } label: {
                                        Image(systemName: selected.contains(batch.id)
                                            ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(purple)
                                    }
                                }
                                ForEach(batch.codes, id: \.self) { c in
                                    HStack(spacing: 8) {
                                        Button {
                                            if selectedCodes.contains(c) { selectedCodes.remove(c) }
                                            else { selectedCodes.insert(c) }
                                        } label: {
                                            Image(systemName: selectedCodes.contains(c)
                                                ? "checkmark.square.fill" : "square")
                                                .foregroundColor(purple)
                                        }
                                        Text(c)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                        Spacer()
                                        Button { UIPasteboard.general.string = c } label: {
                                            Image(systemName: "doc.on.doc")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(12)
                            .background(Color(.systemGray6).opacity(0.5))
                            .cornerRadius(16)
                        }
                    }

                    Text("安全提示：旧卡密数据库只保存不可逆哈希，无法恢复明文。近期记录保存在本机，请及时复制到安全位置。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(24)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(purple.ignoresSafeArea())
        .onAppear(perform: loadHistory)
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
