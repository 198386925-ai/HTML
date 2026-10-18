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

    enum CodingKeys: String, CodingKey {
        case id, code, label
        case maxDevices = "max_devices"
        case deviceCount = "device_count"
        case expiresAt = "expires_at"
        case disabled
        case createdAt = "created_at"
    }

    var statusText: String {
        if disabled { return "已停用" }
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
    let quantity: Int
    let codes: [String]

    init(label: String, quantity: Int, codes: [String]) {
        self.id = UUID()
        self.date = Date()
        self.label = label
        self.quantity = quantity
        self.codes = codes
    }
}
