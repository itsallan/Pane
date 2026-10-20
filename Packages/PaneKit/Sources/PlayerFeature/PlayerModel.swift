import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class PlayerModel {
    static let skipInterval = Duration.seconds(10)
    static let autoHideDelay = Duration.seconds(3)
    static let seekTolerance = Duration.seconds(1)
    static let seekTimeout = Duration.seconds(2)
    static let boostedRate = 2.0
    static let thumbnailPixelSize = 320

    public let title: String?

    public private(set) var status = PlaybackState.Status.idle
    public private(set) var position = Duration.zero
    public private(set) var duration: Duration?
    public private(set) var chapters: [Chapter] = []
    public private(set) var rate = 1.0
    public private(set) var volume = 1.0
    public private(set) var videoScaling = VideoScaling.fit
    public private(set) var isSeekable = false
    public private(set) var tracks: [MediaTrack] = []
    public private(set) var selectedTrackIDs: Set<MediaTrack.ID> = []
    public private(set) var loadFailure: PlaybackError?

    public private(set) var areControlsVisible = true
    public private(set) var isScrubbing = false
    public private(set) var scrubThumbnail: URL?
    public private(set) var isSpeedBoosted = false
    public private(set) var brightness: Double?
    public var isMenuPresented = false {
        didSet {
            guard isMenuPresented != oldValue else { return }
            isMenuPresented ? revealControls() : scheduleAutoHide()
        }
    }

    private let engine: any PlaybackEngine
    private let source: MediaSource
    private let thumbnails: (any ThumbnailProvider)?
    private let screenBrightness: (any ScreenBrightness)?
    private let elapsed: @Sendable () -> Duration
    private let sleep: @Sendable (Duration) async throws -> Void

    // VLC keeps reporting the pre-seek time for a moment after a seek, which would snap the playhead back.
    private var pendingSeek: (target: Duration, deadline: Duration)?
    private var isAdjustingVolume = false
    private var rateBeforeBoost = 1.0
    private var hasStartedLoading = false
    private var hideTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?
    private var requestedThumbnailSecond: Int64?

    public init<C: Clock<Duration>>(
        engine: any PlaybackEngine,
        source: MediaSource,
        title: String? = nil,
        thumbnails: (any ThumbnailProvider)? = nil,
        screenBrightness: (any ScreenBrightness)? = nil,
        clock: C = ContinuousClock()
    ) {
        self.engine = engine
        self.source = source
        self.title = title
        self.thumbnails = thumbnails
        self.screenBrightness = screenBrightness
        let origin = clock.now
        elapsed = { origin.duration(to: clock.now) }
        sleep = { try await clock.sleep(for: $0) }
        brightness = screenBrightness?.level
    }

    public var failure: PlaybackError? {
        if let loadFailure { return loadFailure }
        if case .failed(let error) = status { return error }
        return nil
    }

    public var isPlaying: Bool { status == .playing }

    /// Playing, or about to be once it has buffered. The transport shows pause for all of these.
    public var isPlaybackActive: Bool {
        switch status {
        case .playing, .opening, .buffering: true
        default: false
        }
    }

    public var isBuffering: Bool {
        switch status {
        case .opening, .buffering: true
        default: false
        }
    }

    public var canScrub: Bool { isSeekable && (duration ?? .zero) > .zero }

    public var fraction: Double {
        guard let duration, duration > .zero else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    public var currentChapter: Chapter? {
        chapters.last { $0.start <= position }
    }

    public func run() async {
        let states = engine.states()
        if !hasStartedLoading {
            hasStartedLoading = true
            await load()
        }
        for await state in states {
            apply(state)
        }
    }

    public func retry() {
        Task { await load() }
    }

    public func togglePlayback() {
        revealControls()
        if status == .ended {
            seek(to: .zero)
            Task { [engine] in await engine.play() }
        } else if isPlaybackActive {
            Task { [engine] in await engine.pause() }
        } else {
            Task { [engine] in await engine.play() }
        }
    }

    public func skip(by offset: Duration) {
        revealControls()
        seek(to: position + offset)
    }

    public func seek(toChapter chapter: Chapter) {
        revealControls()
        beginPendingSeek(to: chapter.start)
        Task { [engine] in await engine.seek(toChapter: chapter.id) }
    }

    public func setRate(_ rate: Double) {
        isSpeedBoosted = false
        self.rate = rate
        Task { [engine] in await engine.setRate(rate) }
    }

    public func selectTrack(_ track: MediaTrack) {
        Task { [engine] in try? await engine.selectTrack(track.id) }
    }

    public func turnOffSubtitles() {
        Task { [engine] in await engine.deselectTrack(kind: .subtitle) }
    }

    public func toggleVideoScaling() {
        let next: VideoScaling = videoScaling == .fit ? .fill : .fit
        videoScaling = next
        Task { [engine] in await engine.setVideoScaling(next) }
    }

    private func load() async {
        loadFailure = nil
        do {
            try await engine.load(source)
        } catch {
            loadFailure = error
        }
    }

    private func seek(to target: Duration) {
        guard isSeekable else { return }
        let clamped = clamp(target)
        beginPendingSeek(to: clamped)
        Task { [engine] in await engine.seek(to: clamped, precision: .exact) }
    }

    private func beginPendingSeek(to target: Duration) {
        position = clamp(target)
        pendingSeek = (position, elapsed() + Self.seekTimeout)
    }

    private func clamp(_ position: Duration) -> Duration {
        min(max(position, .zero), duration ?? position)
    }
}

// MARK: - Scrubbing

extension PlayerModel {
    public func beginScrub() {
        guard canScrub, !isScrubbing else { return }
        isScrubbing = true
        revealControls()
        requestThumbnail(at: position)
    }

    public func scrub(toFraction fraction: Double) {
        guard isScrubbing, let duration else { return }
        position = duration * min(max(fraction, 0), 1)
        requestThumbnail(at: position)
    }

    public func endScrub() {
        guard isScrubbing else { return }
        isScrubbing = false
        thumbnailTask?.cancel()
        requestedThumbnailSecond = nil
        scrubThumbnail = nil
        seek(to: position)
        scheduleAutoHide()
    }

    private func requestThumbnail(at position: Duration) {
        guard let thumbnails else { return }
        let second = position.components.seconds
        guard second != requestedThumbnailSecond else { return }
        requestedThumbnailSecond = second
        thumbnailTask?.cancel()
        thumbnailTask = Task { [weak self, source] in
            let url = try? await thumbnails.thumbnail(for: source, at: position, maxPixelSize: Self.thumbnailPixelSize)
            guard let url, !Task.isCancelled, let self, self.isScrubbing else { return }
            self.scrubThumbnail = url
        }
    }
}

// MARK: - Gestures

extension PlayerModel {
    public func beginSpeedBoost() {
        guard isPlaying, !isSpeedBoosted else { return }
        rateBeforeBoost = rate
        isSpeedBoosted = true
        rate = Self.boostedRate
        Task { [engine] in await engine.setRate(Self.boostedRate) }
    }

    public func endSpeedBoost() {
        guard isSpeedBoosted else { return }
        isSpeedBoosted = false
        let restored = rateBeforeBoost
        rate = restored
        Task { [engine] in await engine.setRate(restored) }
    }

    public func beginVolumeAdjustment() {
        isAdjustingVolume = true
    }

    /// `0...2`; above 1 is boost.
    public func setVolume(_ level: Double) {
        let level = min(max(level, 0), 2)
        volume = level
        Task { [engine] in await engine.setVolume(level) }
    }

    public func endVolumeAdjustment() {
        isAdjustingVolume = false
    }

    public var canAdjustBrightness: Bool { screenBrightness != nil }

    public func setBrightness(_ level: Double) {
        guard let screenBrightness else { return }
        let level = min(max(level, 0), 1)
        screenBrightness.level = level
        brightness = level
    }
}

// MARK: - Controls visibility

extension PlayerModel {
    public func toggleControls() {
        if areControlsVisible, !isScrubbing {
            hideTask?.cancel()
            areControlsVisible = false
        } else {
            revealControls()
        }
    }

    public func revealControls() {
        areControlsVisible = true
        scheduleAutoHide()
    }

    private var canAutoHide: Bool {
        isPlaying && !isScrubbing && !isMenuPresented
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        guard areControlsVisible, canAutoHide else { return }
        hideTask = Task { [weak self, sleep] in
            do {
                try await sleep(Self.autoHideDelay)
            } catch {
                return
            }
            guard let self, self.canAutoHide else { return }
            self.areControlsVisible = false
        }
    }
}

// MARK: - State

extension PlayerModel {
    // Each field is copied only when it changed, so a position tick doesn't invalidate the track menu.
    private func apply(_ state: PlaybackState) {
        let previousStatus = status
        assign(\.status, state.status)
        assign(\.duration, state.progress.duration)
        assign(\.chapters, state.chapters)
        assign(\.videoScaling, state.videoScaling)
        assign(\.isSeekable, state.isSeekable)
        assign(\.tracks, state.tracks)
        assign(\.selectedTrackIDs, state.selectedTrackIDs)
        if !isSpeedBoosted {
            assign(\.rate, state.rate)
        }
        if !isAdjustingVolume {
            assign(\.volume, state.volume)
        }
        receive(position: state.progress.position)

        guard status != previousStatus else { return }
        switch status {
        case .playing:
            scheduleAutoHide()
        case .opening, .buffering:
            // A stall mid-playback shouldn't pop the controls up; the hide timer just won't fire until playing resumes.
            break
        case .idle, .paused, .ended, .failed:
            endSpeedBoost()
            revealControls()
        }
    }

    private func receive(position incoming: Duration) {
        guard !isScrubbing else { return }
        if let pendingSeek {
            let distance = incoming > pendingSeek.target ? incoming - pendingSeek.target : pendingSeek.target - incoming
            guard distance <= Self.seekTolerance || elapsed() >= pendingSeek.deadline else { return }
            self.pendingSeek = nil
        }
        assign(\.position, incoming)
    }

    private func assign<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<PlayerModel, Value>, _ value: Value) {
        guard self[keyPath: keyPath] != value else { return }
        self[keyPath: keyPath] = value
    }
}
