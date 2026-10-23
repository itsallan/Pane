import Domain
import Foundation
import MediaPlayer
import PlayerFeature
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The lock screen, Control Center, AirPods and media keys, for whichever open player last started playing.
final class NowPlaying {
    private struct Info: Equatable {
        var title: String
        var duration: Duration?
        var isPlaying: Bool
        var rate: Double
        var hasVideo: Bool
        var isSeekable: Bool
        var hasArtwork: Bool
    }

    private static let supportedRates: [Double] = [0.5, 0.75, 1, 1.25, 1.5, 2]
    private static let artworkPixelSize = 600
    // The system extrapolates elapsed time from the rate, so a tick only needs publishing when it disagrees.
    private static let driftTolerance = Duration.seconds(1)

    private let thumbnails: any ThumbnailProvider
    private let center = MPNowPlayingInfoCenter.default()
    private let commands = MPRemoteCommandCenter.shared()
    private var sessions: [PlayerSession] = []
    private var watchers: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var latestStates: [ObjectIdentifier: PlaybackState] = [:]
    private var current: PlayerSession?
    private var artwork: MPMediaItemArtwork?
    private var artworkTask: Task<Void, Never>?
    private var published: (info: Info, position: Duration, at: ContinuousClock.Instant)?

    init(thumbnails: any ThumbnailProvider) {
        self.thumbnails = thumbnails
        registerCommands()
        updateCommands(for: nil)
    }

    func add(_ session: PlayerSession) {
        let id = ObjectIdentifier(session)
        guard watchers[id] == nil else { return }
        sessions.append(session)
        let states = session.engine.states()
        watchers[id] = Task { [weak self, weak session] in
            for await state in states {
                guard let self, let session else { return }
                self.receive(state, from: session)
            }
        }
    }

    func remove(_ session: PlayerSession) {
        let id = ObjectIdentifier(session)
        watchers.removeValue(forKey: id)?.cancel()
        latestStates[id] = nil
        sessions.removeAll { $0 === session }
        guard current === session else { return }
        // Another window may still be playing; it takes over rather than leaving the controls blank.
        let next = sessions.last { latestStates[ObjectIdentifier($0)]?.status == .playing } ?? sessions.last
        makeCurrent(next)
    }

    private func receive(_ state: PlaybackState, from session: PlayerSession) {
        latestStates[ObjectIdentifier(session)] = state
        if current == nil || (state.status == .playing && current !== session) {
            makeCurrent(session)
        } else if current === session {
            publish(state)
        }
    }

    private func makeCurrent(_ session: PlayerSession?) {
        current = session
        published = nil
        artwork = nil
        artworkTask?.cancel()
        guard let session else {
            center.nowPlayingInfo = nil
            #if os(macOS)
            center.playbackState = .stopped
            #endif
            updateCommands(for: nil)
            return
        }
        loadArtwork(for: session.item)
        if let state = latestStates[ObjectIdentifier(session)] {
            publish(state)
        }
    }

    private func loadArtwork(for item: MediaItem) {
        let position = item.duration.map { min($0 * 0.1, .seconds(120)) } ?? .seconds(20)
        artworkTask = Task { [weak self, thumbnails] in
            guard let url = try? await thumbnails.thumbnail(for: item.source, at: position, maxPixelSize: Self.artworkPixelSize),
                  !Task.isCancelled, let self, let image = PlatformImage(contentsOfFile: url.path(percentEncoded: false))
            else { return }
            self.artwork = Self.artwork(from: url, size: image.size)
            if let current = self.current, let state = self.latestStates[ObjectIdentifier(current)] {
                self.publish(state)
            }
        }
    }

    // MediaPlayer calls the handler on its own queue. Built outside the main actor so the closure isn't
    // isolated to it, and it reloads the file rather than sharing an image across threads.
    private nonisolated static func artwork(from url: URL, size: CGSize) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: size) { _ in
            PlatformImage(contentsOfFile: url.path(percentEncoded: false)) ?? PlatformImage()
        }
    }

    private func publish(_ state: PlaybackState) {
        guard let current else { return }
        let info = Info(
            title: current.item.title,
            duration: state.progress.duration,
            isPlaying: state.status == .playing,
            rate: state.rate,
            hasVideo: state.tracks.contains { $0.kind == .video },
            isSeekable: state.isSeekable,
            hasArtwork: artwork != nil
        )
        let position = state.progress.position
        let now = ContinuousClock.now
        if let published, published.info == info {
            let expected = published.position + (now - published.at) * (info.isPlaying ? info.rate : 0)
            let drift = position > expected ? position - expected : expected - position
            guard drift > Self.driftTolerance else { return }
        }
        published = (info, position, now)

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: info.title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position.seconds,
            MPNowPlayingInfoPropertyPlaybackRate: info.isPlaying ? info.rate : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: (info.hasVideo ? MPNowPlayingInfoMediaType.video : .audio).rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: info.duration == nil,
        ]
        if let duration = info.duration {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration.seconds
        }
        if let artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        center.nowPlayingInfo = nowPlayingInfo
        #if os(macOS)
        center.playbackState = switch state.status {
        case .playing, .opening, .buffering: .playing
        case .paused: .paused
        case .idle, .ended, .failed: .stopped
        }
        #endif
        updateCommands(for: state)
    }

    private func updateCommands(for state: PlaybackState?) {
        let isSeekable = state?.isSeekable == true
        commands.playCommand.isEnabled = state != nil
        commands.pauseCommand.isEnabled = state != nil
        commands.togglePlayPauseCommand.isEnabled = state != nil
        commands.skipForwardCommand.isEnabled = isSeekable
        commands.skipBackwardCommand.isEnabled = isSeekable
        commands.changePlaybackPositionCommand.isEnabled = isSeekable && state?.progress.duration != nil
        commands.changePlaybackRateCommand.isEnabled = state != nil
    }

    // MediaPlayer doesn't promise which queue it calls handlers on, so each one copies what it needs
    // out of the event and hops to the main actor, where the player models live.
    private func registerCommands() {
        let interval = PlayerModel.skipInterval.seconds
        commands.skipForwardCommand.preferredIntervals = [NSNumber(value: interval)]
        commands.skipBackwardCommand.preferredIntervals = [NSNumber(value: interval)]
        commands.changePlaybackRateCommand.supportedPlaybackRates = Self.supportedRates.map { NSNumber(value: $0) }

        addTarget(commands.playCommand) { $0.play() }
        addTarget(commands.pauseCommand) { $0.pause() }
        addTarget(commands.togglePlayPauseCommand) { $0.togglePlayback() }
        addTarget(commands.skipForwardCommand) { $0.skip(by: PlayerModel.skipInterval) }
        addTarget(commands.skipBackwardCommand) { $0.skip(by: .zero - PlayerModel.skipInterval) }
        commands.changePlaybackPositionCommand.addTarget { @Sendable [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = Duration.seconds(event.positionTime)
            Task { @MainActor in self?.current?.model.seek(to: position) }
            return .success
        }
        commands.changePlaybackRateCommand.addTarget { @Sendable [weak self] event in
            guard let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            let rate = Double(event.playbackRate)
            Task { @MainActor in self?.current?.model.setRate(rate) }
            return .success
        }
    }

    private func addTarget(_ command: MPRemoteCommand, perform action: @escaping @MainActor (PlayerModel) -> Void) {
        command.addTarget { @Sendable [weak self] _ in
            Task { @MainActor in
                guard let model = self?.current?.model else { return }
                action(model)
            }
            return .success
        }
    }
}

#if os(iOS)
private typealias PlatformImage = UIImage
#else
private typealias PlatformImage = NSImage
#endif

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
