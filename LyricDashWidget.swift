import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LyricDashWidgetBundle: WidgetBundle {
    var body: some Widget {
        LyricsLiveActivity()
    }
}

/// The lyrics card shown on CarPlay, the Lock Screen and the Dynamic Island.
struct LyricsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsAttributes.self) { context in
            LyricsCard(state: context.state, isStale: context.isStale)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.currentLine)
                            .font(.headline)
                            .lineLimit(2)
                        Text(context.state.nextLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "music.note")
            } compactTrailing: {
                Text(context.state.title)
                    .lineLimit(1)
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: "music.note")
            }
        }
        // "small" is the size CarPlay (and Apple Watch) use for this card.
        .supplementalActivityFamilies([.small])
    }
}

struct LyricsCard: View {
    @Environment(\.activityFamily) private var family
    let state: LyricsAttributes.ContentState
    let isStale: Bool

    // If the app stopped refreshing the card, say so instead of showing a frozen line.
    private var mainText: String { isStale ? "Lyrics paused" : state.currentLine }
    private var subText: String { isStale ? "Open LyricDash to resume" : state.nextLine }
    private var header: String {
        if state.title.isEmpty { return "LyricDash" }
        return state.artist.isEmpty ? state.title : state.title + " · " + state.artist
    }

    var body: some View {
        switch family {
        case .small:
            carPlayLayout
        default:
            lockScreenLayout
        }
    }

    /// Compact layout for CarPlay. Uses the system's own colors so it stays
    /// readable in both the light and dark CarPlay looks.
    private var carPlayLayout: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(mainText)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(subText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var lockScreenLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(mainText)
                .font(.title3.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(subText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
