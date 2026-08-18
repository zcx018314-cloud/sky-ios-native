import Foundation
import Combine

// MARK: - 本地登录态存储(UserDefaults)
final class AuthStore: ObservableObject {
    static let shared = AuthStore()

    @Published var token: String?
    @Published var user: User?

    private let tokenKey = "auth_token"
    private let userKey = "auth_user"

    private init() {
        self.token = UserDefaults.standard.string(forKey: tokenKey)
        if let data = UserDefaults.standard.data(forKey: userKey),
           let u = try? JSONDecoder().decode(User.self, from: data) {
            self.user = u
        }
    }

    var isLoggedIn: Bool { token != nil }

    func save(token: String, user: User) {
        self.token = token
        self.user = user
        UserDefaults.standard.set(token, forKey: tokenKey)
        if let d = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(d, forKey: userKey)
        }
    }

    func clear() {
        token = nil
        user = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }
}

// MARK: - 游戏账号存储(UserDefaults, 与网页版 localStorage 对应)
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    @Published var accounts: [Account] = []
    @Published var currentId: String? = nil

    private let listKey = "sky_account_list"
    private let currentKey = "sky_current_id"

    private init() {
        load()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: listKey),
           let list = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = list
        }
        currentId = UserDefaults.standard.string(forKey: currentKey)
    }

    func save() {
        if let d = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(d, forKey: listKey)
        }
        UserDefaults.standard.set(currentId, forKey: currentKey)
    }

    /// 添加账号,已存在返回 false
    func addAccount(id: String, note: String) -> Bool {
        if accounts.contains(where: { $0.id == id }) { return false }
        accounts.append(Account(id: id, note: note))
        currentId = id
        save()
        return true
    }

    func removeAccount(id: String) {
        accounts.removeAll { $0.id == id }
        if currentId == id { currentId = nil }
        save()
    }

    func clearAll() {
        accounts = []
        currentId = nil
        save()
    }

    func currentAccount() -> Account? {
        accounts.first { $0.id == currentId }
    }
}
