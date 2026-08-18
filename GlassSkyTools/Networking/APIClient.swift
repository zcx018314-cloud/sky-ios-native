import Foundation

/// 身高/光翼接口:应用内直接请求真实接口(本地运行,不走网页的 /api/proxy)。
/// 接口地址与 Android 网页版保持一致。
enum APIClient {

    private static let heightURL = "http://156.238.251.116/SH.php?token=qingfeng"
    private static let wingURL   = "http://156.238.251.116/api/wing.php"

    // MARK: 修改身高
    static func setHeight(uid: String, s: Double, h: Double) async throws -> String {
        let url = "\(heightURL)&id=\(uid)&S=\(s)&H=\(h)"
        let body = try await get(url)
        return parseHeightResponse(body)
    }

    // MARK: 光翼:type 1=无翼 2=满翼 3=恢复
    static func setWing(uid: String, type: Int) async throws -> String {
        let url = "\(wingURL)?type=\(type)&id=\(uid)"
        let body = try await get(url)
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "服务器无响应" : trimmed
    }

    // MARK: - 底层 GET
    private static func get(_ urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw APIError(msg: "非法请求地址")
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "GET"
        let (data, _) = try await URLSession.shared.data(for: req)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// 解析身高接口响应:{"success":true} 或 {"error":"..."}
    private static func parseHeightResponse(_ body: String) -> String {
        if body.contains("\"success\":true") {
            return "修改成功！重新登录游戏生效"
        }
        if let range = body.range(of: "\"error\":\"") {
            let start = range.upperBound
            if let end = body[start...].firstIndex(of: "\"") {
                return "错误:" + body[start..<end]
            }
            return "未知错误"
        }
        return "服务器异常"
    }
}
