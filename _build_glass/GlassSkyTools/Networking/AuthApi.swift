import Foundation

/// 账号 API:注册/登录/改资料/改密码/上传头像
enum AuthApi {

    private static let base = "http://120.48.161.149:18700/api"

    // MARK: - 底层 POST(JSON)
    private static func post(_ path: String, _ body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: base + path) else {
            throw APIError(msg: "非法请求地址")
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func assertOK(_ r: [String: Any]) throws {
        if (r["code"] as? Int) != 0 {
            throw APIError(msg: r["msg"] as? String ?? "操作失败")
        }
    }

    // MARK: 注册
    static func register(username: String, password: String) async throws -> AuthResult {
        let r = try await post("/register", ["username": username, "password": password])
        try assertOK(r)
        guard let token = r["token"] as? String,
              let userDict = r["user"] as? [String: Any],
              let user = User(from: userDict) else {
            throw APIError(msg: "返回数据解析失败")
        }
        return AuthResult(token: token, user: user)
    }

    // MARK: 登录
    static func login(username: String, password: String) async throws -> AuthResult {
        let r = try await post("/login", ["username": username, "password": password])
        try assertOK(r)
        guard let token = r["token"] as? String,
              let userDict = r["user"] as? [String: Any],
              let user = User(from: userDict) else {
            throw APIError(msg: "返回数据解析失败")
        }
        return AuthResult(token: token, user: user)
    }

    // MARK: 更新昵称/头像种子
    static func updateProfile(token: String, nickname: String, seed: String) async throws -> User {
        let r = try await post("/update_profile",
                               ["token": token, "nickname": nickname, "avatar_seed": seed])
        try assertOK(r)
        guard let userDict = r["user"] as? [String: Any],
              let user = User(from: userDict) else {
            throw APIError(msg: "返回数据解析失败")
        }
        return user
    }

    // MARK: 修改密码
    static func changePassword(token: String, old: String, new: String) async throws {
        let r = try await post("/change_password",
                               ["token": token, "old_password": old, "new_password": new])
        try assertOK(r)
    }

    // MARK: 上传头像(base64 PNG),返回 URL
    static func uploadAvatar(token: String, pngData: Data) async throws -> String {
        let b64 = pngData.base64EncodedString()
        let r = try await post("/upload_avatar", ["token": token, "image_base64": b64])
        try assertOK(r)
        return r["url"] as? String ?? ""
    }
}
