import Foundation

// MARK: - 总览统计
struct Stats: Decodable {
    let totalDevices: Int
    let activeToday: Int
    let activeWeek: Int
    let banned: Int
    let licenseCount: Int
    let online: Int
    let unlicensed: Int

    enum CodingKeys: String, CodingKey {
        case totalDevices = "total_devices"
        case activeToday = "active_today"
        case activeWeek = "active_week"
        case banned
        case licenseCount = "license_count"
        case online, unlicensed
    }
}

// MARK: - 激活码（卡密）
struct License: Decodable, Identifiable {
    let id: Int
    let code: String?
    let label: String
    let maxDevices: Int
    let deviceCount: Int
    let expiresAt: Int?
    let disabled: Bool
    let createdAt: Int
    let isDeviceGrant: Bool
    let wasDeviceGrant: Bool
    let deviceCodes: [String]

    enum CodingKeys: String, CodingKey {
        case id, code, label
        case maxDevices = "max_devices"
        case deviceCount = "device_count"
        case expiresAt = "expires_at"
        case disabled
        case createdAt = "created_at"
        case isDeviceGrant = "is_device_grant"
        case wasDeviceGrant = "was_device_grant"
        case deviceCodes = "device_codes"
    }

    var statusText: String {
        if disabled { return "已停用" }
        if wasDeviceGrant && !isDeviceGrant { return "已取消授权" }
        if let e = expiresAt, e < Int(Date().timeIntervalSince1970) { return "已过期" }
        return "正常"
    }
}

// MARK: - 设备
struct DeviceInfo: Decodable, Identifiable {
    let id: Int
    let deviceCode: String
    let model: String?
    let osVersion: String?
    let appVersion: String?
    let status: String
    let online: Bool
    let lastSeen: Int
    let label: String?
    let banned: Bool
    let installationCount: Int
    let page: String?
    let activeGrant: Int
    let createdAt: Int
    let installationCodes: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case deviceCode = "device_code"
        case model
        case osVersion = "os_version"
        case appVersion = "app_version"
        case status, online
        case lastSeen = "last_seen"
        case label, banned
        case installationCount = "installation_count"
        case page
        case activeGrant = "active_grant"
        case createdAt = "created_at"
        case installationCodes = "installation_codes"
    }

    /// banned 在服务端可能是 Bool / Int(0/1) / null，兼容解析
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        deviceCode = try c.decode(String.self, forKey: .deviceCode)
        model = try c.decodeIfPresent(String.self, forKey: .model)
        osVersion = try c.decodeIfPresent(String.self, forKey: .osVersion)
        appVersion = try c.decodeIfPresent(String.self, forKey: .appVersion)
        status = try c.decode(String.self, forKey: .status)
        online = (try? c.decode(Bool.self, forKey: .online)) ?? false
        lastSeen = (try? c.decode(Int.self, forKey: .lastSeen)) ?? 0
        label = try c.decodeIfPresent(String.self, forKey: .label)
        if let b = try? c.decode(Bool.self, forKey: .banned) {
            banned = b
        } else if let i = try? c.decode(Int.self, forKey: .banned) {
            banned = i != 0
        } else {
            banned = false
        }
        installationCount = (try? c.decode(Int.self, forKey: .installationCount)) ?? 1
        page = try c.decodeIfPresent(String.self, forKey: .page)
        activeGrant = (try? c.decode(Int.self, forKey: .activeGrant)) ?? 0
        createdAt = (try? c.decode(Int.self, forKey: .createdAt)) ?? 0
        installationCodes = (try? c.decode([String].self, forKey: .installationCodes)) ?? []
    }

    /// 页面映射（与网页版一致）
    var pageName: String {
        switch page {
        case "home": return "首页"
        case "rules": return "规则"
        case "settings": return "设置"
        default: return "—"
        }
    }

    /// meta 行：机型 / iOS x / App x（与网页版一致）
    var metaText: String {
        var parts: [String] = []
        if let m = model, !m.isEmpty { parts.append(m) }
        if let o = osVersion, !o.isEmpty { parts.append("iOS " + o) }
        if let a = appVersion, !a.isEmpty { parts.append("App " + a) }
        return parts.joined(separator: " / ")
    }

    var createdAtText: String {
        guard createdAt > 0 else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(createdAt)))
    }

    var lastSeenText: String {
        let d = Date(timeIntervalSince1970: TimeInterval(lastSeen))
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: d)
    }
}

// MARK: - API 响应包
struct DashboardResp: Decodable {
    let ok: Bool
    let error: String?
    let stats: Stats?
}

struct LicensesResp: Decodable {
    let ok: Bool
    let error: String?
    let licenses: [License]?
}

struct CodesResp: Decodable {
    let ok: Bool
    let error: String?
    let codes: [String]?
}

struct DeviceList: Decodable {
    let devices: [DeviceInfo]
    let total: Int
    let online: Int
}

struct DevicesResp: Decodable {
    let ok: Bool
    let error: String?
    let devices: DeviceList?
}

struct SimpleResp: Decodable {
    let ok: Bool
    let error: String?
}


// MARK: - 设备显示字段
enum DeviceDisplayField: String, Codable, CaseIterable {
    case deviceCode = "deviceCode"  // 设备码
    case license = "license"        // 卡密信息
    case status = "status"          // 状态
    case online = "online"          // 在线状态
    case page = "page"              // 当前页面
    case meta = "meta"              // 设备信息（机型/系统/版本）
    case lastSeen = "lastSeen"      // 活跃时间
    case created = "created"        // 首次登记/安装记录
    case actions = "actions"        // 操作按钮

    var title: String {
        switch self {
        case .deviceCode: return "设备码"
        case .license: return "卡密信息"
        case .status: return "状态"
        case .online: return "在线状态"
        case .page: return "当前页面"
        case .meta: return "设备信息"
        case .lastSeen: return "活跃时间"
        case .created: return "首次登记"
        case .actions: return "操作按钮"
        }
    }
}

// MARK: - 字体大小选项
enum DeviceFontSize: String, Codable, CaseIterable {
    case small, standard, large, extraLarge

    var title: String {
        switch self {
        case .small: return "小"
        case .standard: return "标准"
        case .large: return "大"
        case .extraLarge: return "特大"
        }
    }
}

// MARK: - 布局疏密选项
enum DeviceDensity: String, Codable, CaseIterable {
    case compact, standard, spacious

    var title: String {
        switch self {
        case .compact: return "紧凑"
        case .standard: return "标准"
        case .spacious: return "宽松"
        }
    }

    /// 卡片内行间距
    var vSpacing: CGFloat {
        switch self {
        case .compact: return 2
        case .standard: return 5
        case .spacious: return 10
        }
    }

    /// 卡片上下内边距
    var cardPadding: CGFloat {
        switch self {
        case .compact: return 2
        case .standard: return 4
        case .spacious: return 8
        }
    }
}

// MARK: - 设备显示模板（用户可手动添加多套）
// 模板只管字段与样式
struct DeviceDisplayTemplate: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    /// true=紧凑单行，false=详细卡片
    var compact: Bool
    /// 按显示顺序排列的字段
    var fields: [DeviceDisplayField]
    static var `default`: DeviceDisplayTemplate {
        DeviceDisplayTemplate(name: "详细", compact: false, fields: DeviceDisplayField.allCases)
    }

    static var compactDefault: DeviceDisplayTemplate {
        DeviceDisplayTemplate(name: "紧凑", compact: true, fields: DeviceDisplayField.allCases)
    }

    func has(_ f: DeviceDisplayField) -> Bool { fields.contains(f) }
}

// MARK: - 模板管理器
class DeviceTemplateStore: ObservableObject {
    @Published var templates: [DeviceDisplayTemplate] = []
    @Published var activeId: String = ""

    static let key = "deviceDisplayTemplates"
    static let activeKey = "deviceDisplayActiveTemplate"

    init() { load() }

    var active: DeviceDisplayTemplate {
        templates.first(where: { $0.id == activeId }) ?? .default
    }

    func load() {
        if let d = UserDefaults.standard.data(forKey: Self.key),
           let t = try? JSONDecoder().decode([DeviceDisplayTemplate].self, from: d),
           !t.isEmpty {
            templates = t
        } else {
            templates = [.default, .compactDefault]
        }
        let aid = UserDefaults.standard.string(forKey: Self.activeKey) ?? ""
        activeId = templates.contains(where: { $0.id == aid }) ? aid : templates[0].id
        // 兼容旧版单偏好：迁移为自定义模板
        if let d = UserDefaults.standard.data(forKey: "deviceDisplayPrefs"),
           let old = try? JSONDecoder().decode(OldDeviceDisplayPrefs.self, from: d) {
            var fields: [DeviceDisplayField] = []
            if old.showDeviceCode { fields.append(.deviceCode) }
            if old.showLicense { fields.append(.license) }
            if old.showStatus { fields.append(.status) }
            if old.showOnline { fields.append(.online) }
            if old.showPage { fields.append(.page) }
            if old.showMeta { fields.append(.meta) }
            if old.showLastSeen { fields.append(.lastSeen) }
            if old.showCreated { fields.append(.created) }
            if old.showActions { fields.append(.actions) }
            let migrated = DeviceDisplayTemplate(name: "我的格式", compact: old.compact, fields: fields)
            templates.append(migrated)
            activeId = migrated.id
            UserDefaults.standard.removeObject(forKey: "deviceDisplayPrefs")
            save()
        }
    }

    func save() {
        if let d = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(d, forKey: Self.key)
        }
        UserDefaults.standard.set(activeId, forKey: Self.activeKey)
    }

    func add(name: String, compact: Bool, fields: [DeviceDisplayField]) {
        let t = DeviceDisplayTemplate(name: name, compact: compact, fields: fields)
        templates.append(t)
        activeId = t.id
        save()
    }

    func update(_ t: DeviceDisplayTemplate) {
        if let i = templates.firstIndex(where: { $0.id == t.id }) {
            templates[i] = t
            save()
        }
    }

    func delete(_ t: DeviceDisplayTemplate) {
        templates.removeAll(where: { $0.id == t.id })
        if templates.isEmpty { templates = [.default] }
        if activeId == t.id { activeId = templates[0].id }
        save()
    }

    func activate(_ t: DeviceDisplayTemplate) {
        activeId = t.id
        save()
    }
}

// 旧版单偏好（仅用于迁移）
private struct OldDeviceDisplayPrefs: Codable {
    var compact: Bool = false
    var showDeviceCode: Bool = true
    var showLicense: Bool = true
    var showStatus: Bool = true
    var showOnline: Bool = true
    var showPage: Bool = true
    var showMeta: Bool = true
    var showLastSeen: Bool = true
    var showCreated: Bool = true
    var showActions: Bool = true
}

// MARK: - 原有授权设备（devices 表，最近 200 条）
struct LegacyDevice: Decodable, Identifiable {
    let id: Int
    let deviceCode: String?
    let authMode: String
    let licenseCode: String?
    let lastSeen: Int
    let banned: Bool
    let banReason: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceCode = "device_code"
        case authMode = "auth_mode"
        case licenseCode = "license_code"
        case lastSeen = "last_seen"
        case banned
        case banReason = "ban_reason"
    }

    var lastSeenText: String {
        let d = Date(timeIntervalSince1970: TimeInterval(lastSeen))
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: d)
    }
}

struct LegacyDevicesResp: Decodable {
    let ok: Bool
    let error: String?
    let devices: [LegacyDevice]?
}

struct KamiCreateResp: Decodable {
    let ok: Bool
    let error: String?
    let cards: [String]?
    let amount: Double?
}

// MARK: - 版本管理
struct AppVersion: Decodable, Identifiable {
    let version: String
    let blocked: Bool
    let message: String
    let note: String

    var id: String { version }
}

struct VersionsResp: Decodable {
    let ok: Bool
    let error: String?
    let versions: [AppVersion]?
}

// MARK: - 本地生成记录（激活码）
struct GeneratedBatch: Codable, Identifiable {
    let id: UUID
    let date: Date
    let label: String
    let maxDevices: Int
    let days: Int
    let codes: [String]

    var quantity: Int { codes.count }

    init(label: String, maxDevices: Int, days: Int, codes: [String]) {
        self.id = UUID()
        self.date = Date()
        self.label = label
        self.maxDevices = maxDevices
        self.days = days
        self.codes = codes
    }

    // 兼容旧版本记录
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        date = (try? c.decode(Date.self, forKey: .date)) ?? Date()
        label = (try? c.decode(String.self, forKey: .label)) ?? ""
        maxDevices = (try? c.decode(Int.self, forKey: .maxDevices)) ?? 1
        days = (try? c.decode(Int.self, forKey: .days)) ?? 0
        codes = (try? c.decode([String].self, forKey: .codes)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, date, label, maxDevices, days, codes
    }
}
