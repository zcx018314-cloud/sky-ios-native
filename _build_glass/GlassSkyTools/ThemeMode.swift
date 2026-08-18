import SwiftUI
import Combine

// MARK: - 全局界面模式:true=白天(暖色),false=夜晚(深色)
// 通过 UserDefaults 持久化,启动时读取
final class ThemeMode: ObservableObject {
    static let shared = ThemeMode()

    @Published var isDay: Bool {
        didSet { UserDefaults.standard.set(isDay, forKey: "theme_is_day") }
    }

    private init() {
        self.isDay = UserDefaults.standard.bool(forKey: "theme_is_day")
    }

    func toggle() {
        isDay.toggle()
    }
}
