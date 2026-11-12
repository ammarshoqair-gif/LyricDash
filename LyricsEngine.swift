import ActivityKit
import Foundation
import MediaPlayer

/// Watches Apple Music, finds the lyrics, and keeps the CarPlay card in sync.
@MainActor
final class LyricsEngine: ObservableObject {
    @Published var title = ""
    @Published var artist = ""
    @Published var currentLine = ""
    @Published var nextLine = ""
    @Published var status = "Tap Start, then play a song in Apple Music."
    @Published var isRunning = false
    /// Nudge timing if lyrics run early or late (seconds; + shows lines sooner). Remembered between drives.
    @Published var offset: Double = UserDefaults.standard.double(forKey: "timingOffset") {
        didSet { UserDefaults.standard.set(offset, forKey: "timingOffset") }
    }

    private let player = MPMusicPlayerController.systemMusicPlayer
    private let keepAlive = KeepAlive()
    private var lines: [LyricLine] = []
    private var cache: [String: [LyricLine]] = [:]
    private var songKey = ""
    private var lineIndex = -2
    private var tickCount = 0
    private var lastPush = Date.distantPast
    private var timer: Timer?
    private var fetchTask: Task<Void, Never>?
    private var activity: Activity<LyricsAttributes>?

    /// The card is marked "paused" if the app hasn't refreshed it for this long.
    private let staleAfter: TimeInterval = 60

    // MARK: Start / stop

    func start() async {
        guard !isRunning else { return }

        let access = await LyricsEngine.requestMusicAccess()
        guard access == .authorized else {
            status = "Please allow access: Settings → Apps → LyricDash → Media & Apple Music."
            return
        }
        guard !isRunning else { return }

        isRunning = true
        keepAlive.start()
        player.beginGeneratingPlaybackNotifications()

        songKey = ""
        lines = []
        lineIndex = -2
        title = ""
        artist = ""
        currentLine = "Waiting for a song…"
        nextLine = ""
        status = "Running. Play a song in Apple Music."

        // Clear any card left over from last time, then show a fresh one.
        // (iOS only lets an app start a card while the app is open on screen.)
        activity = nil
        await endAllActivities()
        startActivity()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        fetchTask?.cancel()
        fetchTask = nil
        player.endGeneratingPlaybackNotifications()
        keepAlive.stop()

        isRunning = false
        songKey = ""
        lines = []
        currentLine = ""
        nextLine = ""
        status = "Stopped."

        activity = nil
        Task { await endAllActivities() }
    }

    /// Called whenever the app comes back on screen.
    func appBecameActive() {
        guard isRunning else { return }
        keepAlive.ensureRunning()
        if cardIsGone {
            activity = nil
            startActivity()
            if activity != nil {
                status = lines.isEmpty ? "Running. Play a song in Apple Music." : "Showing lyrics."
            }
        }
    }

    // MARK: Main loop (4 times a second)

    private func tick() {
        guard isRunning else { return }

        tickCount += 1
        if tickCount % 20 == 0 {
            keepAlive.ensureRunning()   // every 5 seconds, make sure we're still awake
        }

        if let item = player.nowPlayingItem {
            let key = "\(item.title ?? "")|\(item.artist ?? "")|\(Int(length(of: item)))"
            if key != songKey {
                songChanged(item, key: key)
            }
            updateLine()
        }

        // Heartbeat: refresh the card regularly so it never looks "paused" while we're running.
        if Date().timeIntervalSince(lastPush) > 20 {
            pushUpdate()
        }
    }

    private func updateLine() {
        guard !lines.isEmpty else { return }
        let now = player.currentPlaybackTime + offset
        guard now.isFinite else { return }

        let index = lines.lastIndex(where: { $0.time <= now }) ?? -1
        guard index != lineIndex else { return }
        lineIndex = index
        currentLine = index >= 0 ? shown(lines[index].text) : "♪"
        nextLine = index + 1 < lines.count ? shown(lines[index + 1].text) : ""
        pushUpdate()
    }

    private func songChanged(_ item: MPMediaItem, key: String) {
        songKey = key
        fetchTask?.cancel()
        fetchTask = nil
        lines = []
        lineIndex = -2

        let songTitle = item.title ?? ""
        let songArtist = item.artist ?? ""
        let duration = length(of: item)
        title = songTitle.isEmpty ? "Unknown song" : songTitle
        artist = songArtist
        nextLine = ""

        guard !songTitle.isEmpty else {
            currentLine = "♪"
            pushUpdate()
            return
        }

        if let saved = cache[key] {
            lines = saved          // played before: no need to download again
            status = "Showing lyrics."
            return
        }

        currentLine = "Finding lyrics…"
        status = "Finding lyrics…"
        pushUpdate()

        fetchTask = Task { @MainActor [weak self] in
            let found = await LyricsService.fetch(title: songTitle, artist: songArtist, duration: duration)
            guard let self, !Task.isCancelled, key == self.songKey else { return }
            if let found, !found.isEmpty {
                self.cache[key] = found
                self.lines = found
                self.lineIndex = -2
                self.status = "Showing lyrics."
                self.updateLine()
            } else {
                self.currentLine = "No synced lyrics for this song"
                self.status = "No synced lyrics found for this song."
                self.pushUpdate()
            }
        }
    }

    private func shown(_ text: String) -> String {
        text.isEmpty ? "♪" : text
    }

    /// Song length in seconds, or 0 if iOS doesn't know it yet.
    private func length(of item: MPMediaItem) -> Double {
        let seconds = item.playbackDuration
        return seconds.isFinite && seconds > 0 && seconds < 86_400 ? seconds : 0
    }

    // MARK: The lyrics card (a Live Activity: CarPlay, Lock Screen, Dynamic Island)

    private var state: LyricsAttributes.ContentState {
        LyricsAttributes.ContentState(title: title, artist: artist, currentLine: currentLine, nextLine: nextLine)
    }

    private var cardIsGone: Bool {
        guard let activity else { return true }
        return activity.activityState == .ended || activity.activityState == .dismissed
    }

    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = "Turn on Live Activities: Settings → Apps → LyricDash → Live Activities."
            return
        }
        do {
            activity = try Activity<LyricsAttributes>.request(
                attributes: LyricsAttributes(),
                content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(staleAfter)),
                pushType: nil
            )
            lastPush = Date()
        } catch {
            status = "Couldn't show the lyrics card: \(error.localizedDescription)"
        }
    }

    private func pushUpdate() {
        lastPush = Date()
        guard let activity else { return }
        if cardIsGone {
            self.activity = nil
            status = "The lyrics card was closed. Open LyricDash to bring it back."
            return
        }
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(staleAfter))
        Task { await activity.update(content) }
    }

    private func endAllActivities() async {
        for old in Activity<LyricsAttributes>.activities {
            await old.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: Permission

    /// Kept off the main actor on purpose: iOS answers this on a background thread.
    nonisolated private static func requestMusicAccess() async -> MPMediaLibraryAuthorizationStatus {
        await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { result in
                continuation.resume(returning: result)
            }
        }
    }
}
