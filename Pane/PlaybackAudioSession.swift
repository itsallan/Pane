#if os(iOS)
import AVFAudio
import os
import PlayerFeature

/// The app's audio session: a movie player's category, plus pausing for calls, other apps and unplugged headphones.
final class PlaybackAudioSession {
    private static let logger = Logger(subsystem: "io.pane.player", category: "audio-session")

    private let players: OpenPlayers
    private let session = AVAudioSession.sharedInstance()
    private var observers: [any NSObjectProtocol] = []
    private var interruptedSessions: [PlayerSession] = []

    init(players: OpenPlayers) {
        self.players = players
    }

    // libvlc's audio output sets the category again every time it starts, with the same values
    // (avaudiosession_common.m). Setting it here first means the session is right before anything plays,
    // and the route change its call triggers is where we check it stayed that way.
    func activate() {
        do {
            try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
        } catch {
            Self.logger.fault("Couldn't set the playback category: \(error)")
        }
        assertConfigured()
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] notification in
                let interruption = Interruption(notification)
                MainActor.assumeIsolated { self?.handle(interruption) }
            },
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] notification in
                let reason = RouteChange(notification)
                MainActor.assumeIsolated { self?.handle(reason) }
            },
        ]
    }

    var isConfigured: Bool {
        session.category == .playback && session.mode == .moviePlayback && session.routeSharingPolicy == .longFormVideo
    }

    private func assertConfigured() {
        guard !isConfigured else { return }
        Self.logger.fault("Audio session is \(self.session.category.rawValue), \(self.session.mode.rawValue), not movie playback")
        assertionFailure("The audio session lost its playback category; background audio, Picture in Picture and Now Playing depend on it.")
    }

    private func handle(_ interruption: Interruption) {
        switch interruption {
        case .began:
            interruptedSessions = players.sessions.filter(\.model.isPlaybackActive)
            interruptedSessions.forEach { $0.model.pause() }
        case .ended(let shouldResume):
            // Only the system knows whether the interruption was something the user expects to come back from,
            // like a call; after an alarm or another app's audio, it leaves it to the user.
            let resumable = interruptedSessions.filter { session in players.sessions.contains { $0 === session } }
            interruptedSessions = []
            guard shouldResume else { return }
            resumable.forEach { $0.model.play() }
        case .ignored:
            break
        }
    }

    private func handle(_ change: RouteChange) {
        switch change {
        case .deviceGone:
            // Headphones unplugged or AirPods taken out: carrying on would play out loud.
            interruptedSessions = []
            players.sessions.filter(\.model.isPlaybackActive).forEach { $0.model.pause() }
        case .categoryChanged:
            assertConfigured()
        case .other:
            break
        }
    }
}

private nonisolated enum Interruption: Sendable {
    case began
    case ended(shouldResume: Bool)
    case ignored

    init(_ notification: Notification) {
        let info = notification.userInfo ?? [:]
        guard let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else {
            self = .ignored
            return
        }
        switch type {
        case .began:
            self = .began
        case .ended:
            let rawOptions = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            self = .ended(shouldResume: AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume))
        @unknown default:
            self = .ignored
        }
    }
}

private nonisolated enum RouteChange: Sendable {
    case deviceGone
    case categoryChanged
    case other

    init(_ notification: Notification) {
        let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
        switch rawReason.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:)) {
        case .oldDeviceUnavailable: self = .deviceGone
        case .categoryChange: self = .categoryChanged
        default: self = .other
        }
    }
}
#endif
