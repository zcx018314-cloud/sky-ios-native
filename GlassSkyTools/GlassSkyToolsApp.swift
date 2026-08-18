import SwiftUI

@main
struct GlassSkyToolsApp: App {
    let themeMode = ThemeMode.shared
    private let crash = CrashReporter.shared  // 启动时安装崩溃捕获

    var body: some Scene {
        WindowGroup {
            MainScreen()
                .environmentObject(themeMode)
        }
    }
}
