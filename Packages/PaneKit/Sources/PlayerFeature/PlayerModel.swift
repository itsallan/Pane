import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class PlayerModel {
    static let autoHideDelay = Duration.seconds(3)
    static let seekTolerance = Duration.seconds(1)
    static let seekTimeout = Duration.seconds(2)
    static let boostedRate = 2.0
    static let rateStep = 0.25
    static let volumeStep = 0.1
    static let shuttleRates = [1.5, 2.0, 3.0]
    static let shuttleRepeatWindow = Duration.seconds(1)
    static let maxShuttleBackStep = 3
    public static let rates = 0.5...3.0
    static let thumbnailPixelSize = 320
    static let resumeOfferDuration = Duration.seconds(10)

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
    public private(set) var isPictureInPictureSupported = false
    public private(set) var isPictureInPictureActive = false
    public private(set) var videoSize: VideoSize?
    public private(set) var skipInterval = PlaybackPreferences().skipInterval
    public private(set) var gestures = GesturePreferences()
    public private(set) var allowsVolumeBoost = true
    /// Where an unfinished item left off, while the resume preference is `.ask` and the offer still stands.
    public private(set) var resumeOffer: Duration?

    public private(set) var areControlsVisible = true
    public private(set) var isScrubbing = false
    public private(set) var scrubThumbnail: URL?
    public private(set) var isSpeedBoosted = false
    public private(set) var brightness: Double?
    public var isMenuPresented = false {
        didSet { presentationDidChange(from: oldValue, to: isMenuPresented) }
    }
    public var isTrackSheetPresented = false {
        didSet { presentationDidChange(from: oldValue, to: isTrackSheetPresented) }
    }
    public var isSpeedPickerPresented = false {
        didSet { presentationDidChange(from: oldValue, to: isSpeedPickerPresented) }
    }
    public var subtitleImportFailed = false
    public let subtitleSync: SubtitleSync
    public let loop: ABLoop
    public let sleepTimer: SleepTimer
    public let snapshot: FrameSnapshot
    public let ambient: AmbientLight

    private let engine: any PlaybackEngine
    private let item: MediaItem
    private let resume: ResumePlayback?
    private let recordProgress: (@Sendable (PlaybackProgress, SaveProgressTrigger) async -> Void)?
    private let pickTracks: PickPreferredTracks?
    private let preferences: (any PreferencesRepository)?
    private let thumbnails: (any ThumbnailProvider)?
    private let screenBrightness: (any ScreenBrightness)?
    private let screenOrientation: (any ScreenOrientation)?
    private let originalBrightness: Double?
    let elapsed: @Sendable () -> Duration
    private let sleep: @Sendable (Duration) async throws -> Void

    // VLC keeps reporting the pre-seek time for a moment after a seek, which would snap the playhead back.
    private var pendingSeek: (target: Duration, deadline: Duration)?
    private var isAdjustingVolume = false
    private var rateBeforeBoost = 1.0
    // Internal for the keyboard shuttle in PlayerModel+Keyboard.swift.
    var rateBeforeShuttle: Double?
    var lastShuttleBack: (step: Int, at: Duration)?
    // Until the resume seek lands, the engine reports the pre-seek time, which must neither show nor be saved.
    private var resumeTarget: Duration?
    private var resumeDeadline: Duration?
    private var hasPickedTracks = false
    private var manualTrackKinds: Set<MediaTrack.Kind> = []
    private var hasAdjustedBrightness = false
    private var progressWrite: Task<Void, Never>?
    private var hasPlayed = false
    private var isClosed = false
    private var hasStartedLoading = false
    private var hideTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?
    private var resumeOfferExpiry: Task<Void, Never>?
    private var requestedThumbnailSecond: Int64?

    /// Plays a source without resuming, saving progress or picking tracks.
    public convenience init<C: Clock<Duration>>(
        engine: any PlaybackEngine,
        source: MediaSource,
        title: String? = nil,
        thumbnails: (any ThumbnailProvider)? = nil,
        screenBrightness: (any ScreenBrightness)? = nil,
        screenOrientation: (any ScreenOrientation)? = nil,
        photoLibrary: (any PhotoLibrary)? = nil,
        clock: C = ContinuousClock()
    ) {
        self.init(
            engine: engine,
            item: MediaItem(title: title ?? "", source: source),
            title: title,
            resume: nil,
            recordProgress: nil,
            pickTracks: nil,
            preferences: nil,
            thumbnails: thumbnails,
            screenBrightness: screenBrightness,
            screenOrientation: screenOrientation,
            photoLibrary: photoLibrary,
            clock: clock
        )
    }

    /// Plays a library item: resumes where it left off, saves progress as it plays, picks the preferred tracks
    /// and applies the playback preferences when it loads.
    public convenience init<C: Clock<Duration>, P: Clock<Duration>>(
        engine: any PlaybackEngine,
        item: MediaItem,
        resume: ResumePlayback,
        saveProgress: SaveProgress<P>,
        pickTracks: PickPreferredTracks,
        preferences: (any PreferencesRepository)? = nil,
        thumbnails: (any ThumbnailProvider)? = nil,
        screenBrightness: (any ScreenBrightness)? = nil,
        screenOrientation: (any ScreenOrientation)? = nil,
        photoLibrary: (any PhotoLibrary)? = nil,
        clock: C = ContinuousClock()
    ) {
        self.init(
            engine: engine,
            item: item,
            title: item.title,
            resume: resume,
            recordProgress: { progress, trigger in try? await saveProgress(progress, trigger: trigger) },
            pickTracks: pickTracks,
            preferences: preferences,
            thumbnails: thumbnails,
            screenBrightness: screenBrightness,
            screenOrientation: screenOrientation,
            photoLibrary: photoLibrary,
            clock: clock
        )
    }

    private init<C: Clock<Duration>>(
        engine: any PlaybackEngine,
        item: MediaItem,
        title: String?,
        resume: ResumePlayback?,
        recordProgress: (@Sendable (PlaybackProgress, SaveProgressTrigger) async -> Void)?,
        pickTracks: PickPreferredTracks?,
        preferences: (any PreferencesRepository)?,
        thumbnails: (any ThumbnailProvider)?,
        screenBrightness: (any ScreenBrightness)?,
        screenOrientation: (any ScreenOrientation)?,
        photoLibrary: (any PhotoLibrary)?,
        clock: C
    ) {
        self.engine = engine
        self.item = item
        subtitleSync = SubtitleSync(engine: engine)
        loop = ABLoop(engine: engine)
        self.title = title
        self.resume = resume
        self.recordProgress = recordProgress
        self.pickTracks = pickTracks
        self.preferences = preferences
        self.thumbnails = thumbnails
        self.screenBrightness = screenBrightness
        self.screenOrientation = screenOrientation
        let origin = clock.now
        elapsed = { origin.duration(to: clock.now) }
        sleep = { try await clock.sleep(for: $0) }
        sleepTimer = SleepTimer(engine: engine, sleep: sleep)
        snapshot = FrameSnapshot(engine: engine, photoLibrary: photoLibrary, sleep: sleep)
        ambient = AmbientLight(engine: engine, sleep: sleep)
        originalBrightness = screenBrightness?.level
        brightness = originalBrightness
        subtitleSync.currentPosition = { [weak self] in self?.position ?? .zero }
        loop.currentPosition = { [weak self] in self?.position ?? .zero }
        subtitleSync.onActiveChange = { [weak self] in self?.revealControls() }
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

    public var hasVideo: Bool { tracks.contains { $0.kind == .video } }

    public var canUsePictureInPicture: Bool { isPictureInPictureSupported && hasVideo }

    public var canRotate: Bool { screenOrientation != nil }

    public func rotate() {
        revealControls()
        screenOrientation?.rotate()
    }

    public func togglePictureInPicture() {
        guard canUsePictureInPicture else { return }
        let isActive = !isPictureInPictureActive
        Task { [engine] in await engine.setPictureInPicture(isActive) }
    }
    public var audioTracks: [MediaTrack] { tracks.filter { $0.kind == .audio } }
    public var subtitleTracks: [MediaTrack] { tracks.filter { $0.kind == .subtitle } }

    public var areSubtitlesOff: Bool {
        !subtitleTracks.contains { selectedTrackIDs.contains($0.id) }
    }

    public func run() async {
        let states = engine.states()
        if !hasStartedLoading {
            hasStartedLoading = true
            await load()
        }
        for await state in states where !isClosed {
            apply(state)
        }
    }

    /// Saves where playback stopped, puts the screen back as it was and closes the engine.
    public func close() async {
        guard !isClosed else { return }
        saveProgress(.close)
        isClosed = true
        sleepTimer.setting = nil
        restoreBrightness()
        screenOrientation?.unlock()
        await progressWrite?.value
        await engine.close()
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

    public func play() {
        guard !isPlaybackActive else { return }
        togglePlayback()
    }

    public func pause() {
        revealControls()
        Task { [engine] in await engine.pause() }
    }

    public func skip(by offset: Duration) {
        revealControls()
        seek(to: position + offset)
    }

    public var canStepFrame: Bool { status == .paused && isSeekable }

    /// Forward only: libvlc has no previous-frame.
    public func stepFrame() {
        guard canStepFrame else { return }
        revealControls()
        Task { [engine] in await engine.stepFrame() }
    }

    public func seek(toChapter chapter: Chapter) {
        revealControls()
        beginPendingSeek(to: chapter.start)
        Task { [engine] in await engine.seek(toChapter: chapter.id) }
    }

    public func setRate(_ rate: Double) {
        let rate = min(max(rate, Self.rates.lowerBound), Self.rates.upperBound)
        isSpeedBoosted = false
        rateBeforeShuttle = nil
        self.rate = rate
        Task { [engine] in await engine.setRate(rate) }
    }

    public func selectTrack(_ track: MediaTrack) {
        manualTrackKinds.insert(track.kind)
        Task { [engine] in try? await engine.selectTrack(track.id) }
    }

    public func turnOffSubtitles() {
        manualTrackKinds.insert(.subtitle)
        Task { [engine] in await engine.deselectTrack(kind: .subtitle) }
    }

    /// Copies the file first: the importer's security scope ends long before libvlc is done reading.
    public func addSubtitle(from url: URL) async {
        manualTrackKinds.insert(.subtitle)
        do {
            let copy = try await SubtitleFile.copy(of: url)
            if let text = await SubtitleFile.text(at: copy) {
                subtitleSync.expect(ParseSubtitleCues()(text), besides: Set(subtitleTracks.map(\.id)))
            }
            try await engine.addSubtitle(from: copy)
        } catch {
            subtitleImportFailed = true
        }
    }

    /// For sliders: snaps to 0.05 so a drag lands on rates people can read.
    public var speed: Double {
        get { rate }
        set { setRate((newValue * 20).rounded() / 20) }
    }

    public var fillsScreen: Bool {
        get { videoScaling == .fill }
        set {
            guard newValue != fillsScreen else { return }
            toggleVideoScaling()
        }
    }

    public func toggleVideoScaling() {
        let next: VideoScaling = videoScaling == .fit ? .fill : .fit
        videoScaling = next
        Task { [engine] in await engine.setVideoScaling(next) }
    }

    private func load() async {
        loadFailure = nil
        hasPickedTracks = false
        let preferences = await loadPreferences()
        do {
            if let resume {
                if let resumed = try await resume(item, behavior: preferences.resume) {
                    awaitResume(at: resumed)
                } else if preferences.resume == .ask, let saved = await resume.savedPosition(for: item) {
                    offerResume(at: saved)
                }
            } else {
                try await engine.load(item.source)
            }
        } catch {
            loadFailure = error
        }
        // The engine starts every load at 1x.
        if loadFailure == nil, preferences.defaultRate != 1 {
            setRate(preferences.defaultRate)
        }
    }

    private func loadPreferences() async -> PlaybackPreferences {
        guard let preferences else { return PlaybackPreferences() }
        let loaded = (try? await preferences.playbackPreferences()) ?? PlaybackPreferences()
        skipInterval = loaded.skipInterval
        gestures = loaded.gestures
        allowsVolumeBoost = loaded.allowsVolumeBoost
        await engine.setHardwareDecoding(loaded.usesHardwareDecoding)
        return loaded
    }

    private func awaitResume(at target: Duration) {
        position = target
        resumeTarget = target
        resumeDeadline = nil
    }

    public func seek(to target: Duration) {
        guard isSeekable else { return }
        let clamped = clamp(target)
        beginPendingSeek(to: clamped)
        Task { [engine] in await engine.seek(to: clamped, precision: .exact) }
    }

    private func beginPendingSeek(to target: Duration) {
        resumeTarget = nil
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
        thumbnailTask = Task { [weak self, item] in
            let url = try? await thumbnails.thumbnail(for: item.source, at: position, maxPixelSize: Self.thumbnailPixelSize)
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

    /// `0...maximumVolume`; above 1 is boost.
    public var maximumVolume: Double { allowsVolumeBoost ? 2 : 1 }

    public func setVolume(_ level: Double) {
        let level = min(max(level, 0), maximumVolume)
        volume = level
        Task { [engine] in await engine.setVolume(level) }
    }

    /// For sliders; the same as `setVolume(_:)`.
    public var volumeLevel: Double {
        get { volume }
        set { setVolume(newValue) }
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
        hasAdjustedBrightness = true
    }

    private func restoreBrightness() {
        guard hasAdjustedBrightness, let screenBrightness, let originalBrightness else { return }
        screenBrightness.level = originalBrightness
    }
}

// MARK: - Resume offer

extension PlayerModel {
    public func acceptResumeOffer() {
        guard let resumeOffer else { return }
        dismissResumeOffer()
        seek(to: resumeOffer)
    }

    public func dismissResumeOffer() {
        resumeOfferExpiry?.cancel()
        resumeOffer = nil
    }

    private func offerResume(at position: Duration) {
        resumeOffer = position
        resumeOfferExpiry = Task { [weak self, sleep] in
            do {
                try await sleep(Self.resumeOfferDuration)
            } catch {
                return
            }
            self?.resumeOffer = nil
        }
    }
}

// MARK: - Scene phase

extension PlayerModel {
    /// The app is about to background, or something (Control Center, an alert) is covering it.
    public func sceneDidResignActive() {
        restoreBrightness()
    }

    /// With `pausesVideo`, audio-only media keeps playing and video stops unless it's in Picture in Picture.
    public func sceneDidEnterBackground(pausesVideo: Bool = false) {
        restoreBrightness()
        saveProgress(.background)
        if pausesVideo, hasVideo, isPlaybackActive, !isPictureInPictureActive {
            pause()
        }
    }

    public func sceneDidBecomeActive() {
        guard hasAdjustedBrightness, let screenBrightness, let brightness else { return }
        screenBrightness.level = brightness
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
        // Called on every pointer move on the Mac, so skip the write when nothing changes.
        if !areControlsVisible {
            areControlsVisible = true
        }
        scheduleAutoHide()
    }

    public func pointerDidLeave() {
        guard areControlsVisible, canAutoHide else { return }
        hideTask?.cancel()
        areControlsVisible = false
    }

    private var canAutoHide: Bool {
        isPlaying && !isScrubbing && !isMenuPresented && !isTrackSheetPresented && !isSpeedPickerPresented
            && !subtitleSync.isActive
    }

    private func presentationDidChange(from oldValue: Bool, to isPresented: Bool) {
        guard isPresented != oldValue else { return }
        isPresented ? revealControls() : scheduleAutoHide()
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
        assign(\.isPictureInPictureSupported, state.isPictureInPictureSupported)
        assign(\.isPictureInPictureActive, state.isPictureInPictureActive)
        assign(\.videoSize, state.videoSize)
        subtitleSync.update(from: state)
        loop.update(from: state)
        if !isSpeedBoosted {
            assign(\.rate, state.rate)
        }
        if !isAdjustingVolume {
            assign(\.volume, state.volume)
        }
        if status == .playing {
            hasPlayed = true
        }
        if status == .playing, resumeTarget != nil, resumeDeadline == nil {
            resumeDeadline = elapsed() + Self.seekTimeout
        }
        let didLandSeek = receive(position: state.progress.position)

        if didLandSeek {
            saveProgress(.seekEnded)
        } else if status == .playing {
            saveProgress(.tick)
        }
        if status == .playing, !hasPickedTracks {
            pickPreferredTracks(for: state)
        }

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
        if status == .ended {
            sleepTimer.itemDidEnd()
        }
        if status == .paused || status == .ended {
            saveProgress(.pause)
        }
    }

    /// Returns whether a seek just landed.
    private func receive(position incoming: Duration) -> Bool {
        guard !isScrubbing else { return false }
        if let resumeTarget {
            let hasTimedOut = resumeDeadline.map { elapsed() >= $0 } ?? false
            guard isNear(incoming, resumeTarget) || hasTimedOut else { return false }
            self.resumeTarget = nil
            resumeDeadline = nil
        }
        var didLand = false
        if let pendingSeek {
            guard isNear(incoming, pendingSeek.target) || elapsed() >= pendingSeek.deadline else { return false }
            self.pendingSeek = nil
            didLand = true
        }
        assign(\.position, incoming)
        return didLand
    }

    private func isNear(_ position: Duration, _ target: Duration) -> Bool {
        let distance = position > target ? position - target : target - position
        return distance <= Self.seekTolerance
    }

    // Tracks arrive one at a time while the input opens; by the first playing state they've settled.
    private func pickPreferredTracks(for state: PlaybackState) {
        guard let pickTracks else { return }
        hasPickedTracks = true
        Task { [manualTrackKinds] in try? await pickTracks(for: state, keeping: manualTrackKinds) }
    }

    // Writes are chained so a pause can't land before the tick that preceded it.
    private func saveProgress(_ trigger: SaveProgressTrigger) {
        // Before anything played, the position is a placeholder, and saving it would wipe the real resume point.
        guard let recordProgress, hasPlayed, !isClosed, !isScrubbing, resumeTarget == nil, pendingSeek == nil else { return }
        let progress = PlaybackProgress(position: position, duration: duration)
        let previous = progressWrite
        progressWrite = Task {
            await previous?.value
            await recordProgress(progress, trigger)
        }
    }

    private func assign<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<PlayerModel, Value>, _ value: Value) {
        guard self[keyPath: keyPath] != value else { return }
        self[keyPath: keyPath] = value
    }
}
