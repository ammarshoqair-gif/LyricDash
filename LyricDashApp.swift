import SwiftUI

@main
struct LyricDashApp: App {
    @StateObject private var engine = LyricsEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
        }
    }
}
