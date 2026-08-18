import Foundation

// MARK: - 登录用户
struct User: Codable, Identifiable, Equatable {
    let id: Int
    let username: String
    let nickname: String
    let avatarSeed: String
}

// MARK: - 游戏账号(本地保存的 UUID)
struct Account: Codable, Identifiable, Equatable {
    let id: String
    let note: String
}

// MARK: - 权限状态
struct PermissionState: Codable {
    let height: Bool
    let wing: Bool
}

// MARK: - 登录结果
struct AuthResult {
    let token: String
    let user: User
}

// MARK: - 聊天消息
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let kind: String      // chat / system
    let from: String
    let fromId: Int
    let seed: String
    let text: String
    let ts: TimeInterval
    let isSelf: Bool
}

// MARK: - 从服务端字典构造(网络层共用)
extension User {
    init?(from dict: [String: Any]) {
        guard let username = dict["username"] as? String else { return nil }
        self.id = dict["id"] as? Int ?? 0
        self.username = username
        self.nickname = dict["nickname"] as? String ?? ""
        self.avatarSeed = dict["avatar_seed"] as? String ?? ""
    }
}

// MARK: - 统一错误类型
struct APIError: LocalizedError {
    let msg: String
    var errorDescription: String? { msg }
}
