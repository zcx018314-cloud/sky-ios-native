import SwiftUI

@main
struct GlassSkyToolsApp: App {
    let themeMode = ThemeMode.shared

    var body: some Scene {
        WindowGroup {
            MainScreen()
                .environmentObject(themeMode)
        }
    }
}
