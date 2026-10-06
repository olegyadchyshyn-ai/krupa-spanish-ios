import SwiftUI

/// Точка входу застосунку KRUPA Spanish.
@main
struct KrupaSpanishApp: App {

    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(app.preferredColorScheme)
                .tint(.krupaBrand)
        }
    }
}
