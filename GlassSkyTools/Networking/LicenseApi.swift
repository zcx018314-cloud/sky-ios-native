import Foundation

/// 权限卡密 API(卡密系统,端口 18689)
enum LicenseApi {

    private static let base = "http://120.48.161.149:18689"

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

    /// 查询账号权限(只读,不消耗卡密)。success 缺省视为 1(成功)
    static func checkPermission(accountId: String) async throws -> PermissionState {
        let r = try await post("/api/check_permission", ["account_id": accountId])
        let success = r["success"] as? Int ?? 1
        if success != 1 { throw APIError(msg: r["error"] as? String ?? "查询失败") }
        let p = r["permissions"] as? [String: Any]
        return PermissionState(
            height: p?["height"] as? Bool ?? false,
            wing: p?["wing"] as? Bool ?? false
        )
    }

    /// 激活权限卡密:type=height/wing,激活即永久,绑定当前账号
    static func verifyPermission(code: String, accountId: String, type: String) async throws -> String {
        let r = try await post("/api/verify_permission",
                               ["license_code": code, "account_id": accountId, "permission_type": type])
        if (r["success"] as? Int) != 1 { throw APIError(msg: r["error"] as? String ?? "激活失败") }
        return r["message"] as? String ?? "激活成功"
    }

    /// 游戏ID全局唯一登记:添加账号时调用(不同账号不可共用,同账号不可重复)
    static func registerGameId(accountId: String, gameId: String) async throws -> String {
        let r = try await post("/api/register_game_id", ["account_id": accountId, "game_id": gameId])
        if (r["success"] as? Int) != 1 { throw APIError(msg: r["error"] as? String ?? "ID登记失败") }
        return r["message"] as? String ?? "ID登记成功"
    }

    /// 查询登录账号已成功使用过的游戏ID列表(有效账号,上限2)
    static func checkGameUsage(accountId: String) async throws -> [String] {
        let r = try await post("/api/check_game_usage", ["account_id": accountId])
        if (r["success"] as? Int) != 1 { throw APIError(msg: r["error"] as? String ?? "查询失败") }
        let arr = r["used"] as? [String] ?? []
        return arr
    }

    /// 记录登录账号成功使用过的游戏ID(超2个会被拒绝)
    static func recordGameUsage(accountId: String, gameId: String) async throws {
        let r = try await post("/api/record_game_usage", ["account_id": accountId, "game_id": gameId])
        if (r["success"] as? Int) != 1 { throw APIError(msg: r["error"] as? String ?? "记录失败") }
    }

    /// 获取账号登记过的游戏ID列表(清数据/换设备后同步本地)
    static func getGameIds(accountId: String) async throws -> [String] {
        let r = try await post("/api/get_game_ids", ["account_id": accountId])
        if (r["success"] as? Int) != 1 { throw APIError(msg: r["error"] as? String ?? "同步失败") }
        let arr = r["game_ids"] as? [String] ?? []
        return arr
    }
}
