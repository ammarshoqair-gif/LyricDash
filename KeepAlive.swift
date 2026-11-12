import AVFoundation

/// Plays a silent loop (mixed with Apple Music) so iOS keeps the app awake
/// while you drive. Without this, lyrics freeze as soon as the phone locks.
///
/// It restarts itself after the things that normally stop audio:
/// plugging into CarPlay (audio route change), phone calls, and Siri.
final class KeepAlive: @unchecked Sendable {
    private var player: AVAudioPlayer?
    private var wanted = false
    private var observers: [NSObjectProtocol] = []

    init() {
        let names: [Notification.Name] = [
            AVAudioSession.interruptionNotification,
            AVAudioSession.routeChangeNotification,
            AVAudioSession.mediaServicesWereResetNotification,
        ]
        for name in names {
            let token = NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] note in
                self?.handle(note)
            }
            observers.append(token)
        }
    }

    deinit {
        for token in observers {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func start() {
        wanted = true
        ensureRunning()
    }

    func stop() {
        wanted = false
        player?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    /// Safe to call often. Restarts the silent loop if iOS stopped it.
    func ensureRunning() {
        guard wanted else { return }
        if let current = player, current.isPlaying { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        if player == nil {
            let fresh = try? AVAudioPlayer(data: KeepAlive.silentWAV())
            fresh?.numberOfLoops = -1   // loop forever
            player = fresh
        }
        player?.prepareToPlay()
        player?.play()
    }

    private func handle(_ note: Notification) {
        if note.name == AVAudioSession.mediaServicesWereResetNotification {
            player = nil   // the old player is dead after a reset
        }
        if note.name == AVAudioSession.interruptionNotification,
           let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
           AVAudioSession.InterruptionType(rawValue: raw) == .began {
            return   // a call or Siri just started; wait for it to end
        }
        ensureRunning()
    }

    // MARK: A tiny silent sound file, built in memory

    private static func silentWAV() -> Data {
        let sampleRate: UInt32 = 44_100
        let seconds: UInt32 = 2
        let dataSize: UInt32 = sampleRate * 2 * seconds   // 16-bit, mono

        var wav = Data()
        wav.append(contentsOf: Array("RIFF".utf8))
        wav.append(contentsOf: bytes(UInt32(36) + dataSize))
        wav.append(contentsOf: Array("WAVE".utf8))
        wav.append(contentsOf: Array("fmt ".utf8))
        wav.append(contentsOf: bytes(UInt32(16)))         // format chunk size
        wav.append(contentsOf: bytes(UInt16(1)))          // PCM
        wav.append(contentsOf: bytes(UInt16(1)))          // mono
        wav.append(contentsOf: bytes(sampleRate))
        wav.append(contentsOf: bytes(sampleRate * 2))     // bytes per second
        wav.append(contentsOf: bytes(UInt16(2)))          // bytes per sample
        wav.append(contentsOf: bytes(UInt16(16)))         // bits per sample
        wav.append(contentsOf: Array("data".utf8))
        wav.append(contentsOf: bytes(dataSize))
        wav.append(Data(count: Int(dataSize)))            // all zeros = silence
        return wav
    }

    private static func bytes<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian) { Array($0) }
    }
}
