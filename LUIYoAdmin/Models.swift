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

// MARK: - 设备显示格式偏好（用户自定义）
struct DeviceDisplayPrefs: Codable {
    /// 卡片样式：true=紧凑， false=详细
    var compact: Bool = false
    var showDeviceCode: Bool = true  // 设备码
    var showLicense: Bool = true     // 卡密信息（备注/授权来源）
    var showStatus: Bool = true      // 状态（已授权/未授权/已封禁…）
    var showOnline: Bool = true      // ●在线/离线
    var showPage: Bool = true        // 当前页面（首页/规则/设置）
    var showMeta: Bool = true        // 设备信息（机型/iOS/App版本）
    var showLastSeen: Bool = true    // 活跃时间
    var showCreated: Bool = true     // 首次登记 + 安装记录
    var showActions: Bool = true     // 操作按钮（授权/修改设备）

    static let key = "deviceDisplayPrefs"

    static func load() -> DeviceDisplayPrefs {
        if let d = UserDefaults.standard.data(forKey: key),
           let p = try? JSONDecoder().decode(DeviceDisplayPrefs.self, from: d) {
            return p
        }
        return DeviceDisplayPrefs()
    }

    func save() {
        if let d = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(d, forKey: Self.key)
        }
    }
}

// MARK: - 原有授权设备（devices 表，最近 200 条）
struct LegacyDevice: Decodable, Identifiable {
    let id: Int
    let deviceCode: String?
    let authMode: String
    let lastSeen: Int
    let banned: Bool
    let banReason: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceCode = "device_code"
        case authMode = "auth_mode"
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
