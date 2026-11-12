import ActivityKit

/// The data shared between the app and the CarPlay / Lock Screen display.
struct LyricsAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var artist: String
        var currentLine: String
        var nextLine: String
    }
}
