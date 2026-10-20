import Foundation

enum APIError: LocalizedError {
    case notLoggedIn
    case server(String)
    case network(Error)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "登录已过期，请重新登录"
        case .server(let m): return m
        case .network(let e): return "网络错误：\(e.localizedDescription)"
        case .badResponse: return "服务器返回异常"
        }
    }
}

/// 后台管理接口客户端（api-native-v2.php，session 会话鉴权）
@MainActor
class AdminAPI: ObservableObject {
    static let shared = AdminAPI()

    @Published var loggedIn = false
    @Published var serverBase: String = UserDefaults.standard.string(forKey: "serverBase")
        ?? "https://mistoto.cc.cd/luiyo"

    private var base: String {
        serverBase.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func saveServer(_ s: String) {
        serverBase = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        UserDefaults.standard.set(serverBase, forKey: "serverBase")
    }

    // MARK: - 登录/登出

    func login(password: String) async throws {
        let r: SimpleResp = try await post(action: "login", params: ["password": password])
        guard r.ok else { throw APIError.server(r.error ?? "登录失败") }
        loggedIn = true
    }

    func logout() {
        // 服务端无登出接口：清掉该站点的 cookie 即登出
        if let url = URL(string: base),
           let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for c in cookies { HTTPCookieStorage.shared.deleteCookie(c) }
        }
        loggedIn = false
    }

    // MARK: - 总览

    func dashboard() async throws -> Stats {
        let r: DashboardResp = try await post(action: "dashboard", params: [:])
        guard r.ok, let s = r.stats else { throw APIError.server(r.error ?? "获取失败") }
        return s
    }

    // MARK: - 激活码

    func licenses() async throws -> [License] {
        let r: LicensesResp = try await post(action: "licenses", params: [:])
        guard r.ok, let list = r.licenses else { throw APIError.server(r.error ?? "获取失败") }
        return list
    }

    func createLicense(label: String, maxDevices: Int, days: Int, quantity: Int) async throws -> [String] {
        let r: CodesResp = try await post(action: "create_license", params: [
            "label": label,
            "max_devices": String(maxDevices),
            "days": String(days),
            "quantity": String(quantity),
        ])
        guard r.ok, let codes = r.codes else { throw APIError.server(r.error ?? "生成失败") }
        return codes
    }

    func licenseAction(id: Int, op: String) async throws {
        let r: SimpleResp = try await post(action: "license_action", params: [
            "id": String(id), "op": op,
        ])
        guard r.ok else { throw APIError.server(r.error ?? "操作失败") }
    }

    // MARK: - 设备

    func devices() async throws -> [DeviceInfo] {
        let r: DevicesResp = try await post(action: "devices", params: [:])
        guard r.ok, let list = r.devices?.devices else { throw APIError.server(r.error ?? "获取失败") }
        return list
    }

    /// op: ban / unban / grant / revoke
    func deviceAction(id: Int, deviceCode: String, op: String, reason: String = "") async throws {
        var p = ["id": String(id), "op": op, "device_code": deviceCode]
        if !reason.isEmpty { p["reason"] = reason }
        let r: SimpleResp = try await post(action: "device_action", params: p)
        guard r.ok else { throw APIError.server(r.error ?? "操作失败") }
    }

    /// 原有授权设备封禁/解封（按 devices.id）
    func legacyDeviceAction(legacyId: Int, op: String, reason: String = "") async throws {
        var p = ["legacy_id": String(legacyId), "op": op]
        if !reason.isEmpty { p["reason"] = reason }
        let r: SimpleResp = try await post(action: "device_action", params: p)
        guard r.ok else { throw APIError.server(r.error ?? "操作失败") }
    }

    /// 修改设备码（与网页版一致）
    func modifyDeviceCode(deviceCode: String, newCode: String) async throws {
        let p = ["op": "modify_device_code", "device_code": deviceCode, "new_code": newCode]
        let r: SimpleResp = try await post(action: "device_action", params: p)
        guard r.ok else { throw APIError.server(r.error ?? "操作失败") }
    }

    func legacyDevices() async throws -> [LegacyDevice] {
        let r: LegacyDevicesResp = try await post(action: "legacy_devices", params: [:])
        guard r.ok, let list = r.devices else { throw APIError.server(r.error ?? "获取失败") }
        return list
    }

    // MARK: - 版本管理

    func versions() async throws -> [AppVersion] {
        let r: VersionsResp = try await post(action: "versions", params: [:])
        guard r.ok, let list = r.versions else { throw APIError.server(r.error ?? "获取失败") }
        return list
    }

    /// op: add / block / unblock / delete
    func versionAction(op: String, version: String, note: String = "", message: String = "") async throws {
        var p = ["op": op, "version": version]
        if !note.isEmpty { p["note"] = note }
        if !message.isEmpty { p["message"] = message }
        let r: SimpleResp = try await post(action: "version_action", params: p)
        guard r.ok else { throw APIError.server(r.error ?? "操作失败") }
    }

    // MARK: - 上传 IPA（主 App 更新包）

    struct UploadIPAResp: Decodable {
        let ok: Bool
        let error: String?
        let filename: String?
        let download_url: String?
    }

    /// 上传 IPA 到服务器。password 取 Keychain 里存的管理员密码。
    func uploadIPA(fileURL: URL, version: String, build: String, changelog: String) async throws -> UploadIPAResp {
        guard let password = Keychain.load(), !password.isEmpty else {
            throw APIError.server("未保存密码，请重新登录并勾选记住密码")
        }
        guard let url = URL(string: base + "/upload-ipa.php") else {
            throw APIError.server("服务器地址无效")
        }
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw APIError.server("读取 IPA 文件失败")
        }
        let filename = fileURL.lastPathComponent
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        // 文件字段
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        // 文本字段
        appendField("version", version)
        appendField("build", build)
        appendField("changelog", changelog)
        appendField("password", password)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.upload(for: req, from: body)
        } catch {
            throw APIError.network(error)
        }
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.badResponse
        }
        do {
            let r = try JSONDecoder().decode(UploadIPAResp.self, from: data)
            guard r.ok else { throw APIError.server(r.error ?? "上传失败") }
            return r
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.badResponse
        }
    }

    // MARK: - 底层

    private func post<T: Decodable>(action: String, params: [String: String]) async throws -> T {
        guard let url = URL(string: base + "/api-native-v2.php") else {
            throw APIError.server("服务器地址无效")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 25
        var items = [URLQueryItem(name: "action", value: action)]
        for (k, v) in params { items.append(URLQueryItem(name: k, value: v)) }
        var comps = URLComponents()
        comps.queryItems = items
        req.httpBody = comps.percentEncodedQuery?.data(using: .utf8)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.network(error)
        }
        guard let http = resp as? HTTPURLResponse else { throw APIError.badResponse }
        if http.statusCode == 401 {
            loggedIn = false
            throw APIError.notLoggedIn
        }
        guard http.statusCode == 200 else { throw APIError.badResponse }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.badResponse
        }
    }
}
