import CoreGraphics
import Domain
import Foundation
@preconcurrency import VLCKit

public actor VLCPlaybackEngine: PlaybackEngine {
    private struct PendingCapture {
        let id: UUID
        let url: URL
        let continuation: CheckedContinuation<Result<URL, PlaybackError>, Never>
    }

    // VLCMediaPlayer.stop and media replacement can block while libvlc tears down outputs, so none of it runs on main.
    private let queue = DispatchSerialQueue(label: "io.pane.player.playback", qos: .userInitiated)
    public nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    private let player: VLCMediaPlayer
    private let bridge = PlayerEventBridge()
    private let broadcast = StateBroadcast()
    private let capabilitiesObserver: any NSObjectProtocol
    private let captureDirectory: URL
    private let servers: (any NetworkServerRepository)?
    private let credentials: (any CredentialStore)?
    private let responder: LoginResponder

    private var state = PlaybackState()
    private var location: MediaLocation?
    private var vlcState = VLCMediaPlayerState.stopped
    private var bufferFill = 1.0
    private var length: Duration?
    private var isTimeTrusted = false
    private var lastUntrustedTime: Duration?
    private var failure: PlaybackError?
    private var isInputOpen = false
    private var hasEnded = false
    private var pendingSeek: Duration?
    private var isNativeLoop = false
    private var defaultTrackIDs: Set<MediaTrack.ID> = []
    private var isTrackSelectionManual = false
    private var pendingCaptures: [PendingCapture] = []
    private var pendingSlave: (title: String, existingIDs: Set<MediaTrack.ID>)?
    private var slaveTitles: [MediaTrack.ID: String] = [:]
    private var isClosed = false
    private var share: (server: NetworkServer.ID, login: UUID)?

    init(
        drawable: VideoDrawable?,
        subtitleStyle: SubtitleStyle = SubtitleStyle(),
        servers: (any NetworkServerRepository)? = nil,
        credentials: (any CredentialStore)? = nil
    ) {
        let options = subtitleStyle.libraryOptions
        // initWithOptions creates a private libvlc instance, which costs memory; only pay for it when the style needs one.
        player = options.isEmpty ? VLCMediaPlayer() : VLCMediaPlayer(options: options)
        // Login dialogs are per libvlc instance, so a private instance needs its own responder.
        responder = options.isEmpty ? .shared : LoginResponder(library: player.libraryInstance)
        self.servers = servers
        self.credentials = credentials
        player.currentSubTitleFontScale = subtitleStyle.fontScale
        // VLCKit interpolates time on a main run loop timer that defaults to 1 s; 4 Hz keeps the scrubber smooth.
        player.timeChangeUpdateInterval = 0.25
        // The delegate is weak; the actor keeps the bridge alive.
        player.delegate = bridge
        if let drawable {
            player.drawable = drawable
        }
        captureDirectory = URL.cachesDirectory.appending(path: "Snapshots", directoryHint: .isDirectory)

        // Seekability has no delegate callback, only this notification. It's posted on libvlc's event thread.
        let bridge = bridge
        capabilitiesObserver = NotificationCenter.default.addObserver(
            forName: VLCMediaPlayer.capabilitiesChangedNotification,
            object: player,
            queue: nil
        ) { _ in
            bridge.yield(.capabilitiesChanged)
        }

        let events = bridge.events
        Task { [weak self] in
            for await event in events {
                await self?.handle(event)
            }
        }
    }

    isolated deinit {
        NotificationCenter.default.removeObserver(capabilitiesObserver)
        player.delegate = nil
        player.stop()
        location?.relinquish()
        endShareLogin()
        bridge.finish()
        broadcast.finish()
        failPendingCaptures()
    }

    public nonisolated func states() -> AsyncStream<PlaybackState> {
        broadcast.subscribe()
    }

    public func load(_ source: MediaSource) async throws(PlaybackError) {
        guard !isClosed else { return }
        let resolved = try await resolveShare(for: source)
        guard !isClosed else { return }
        let location = try MediaLocation(source, share: resolved?.address)
        guard let media = location.makeMedia() else {
            location.relinquish()
            throw .playbackFailure(isRemote: location.isRemote)
        }
        self.location?.relinquish()
        self.location = location
        endShareLogin()
        if let resolved {
            share = (resolved.server.id, responder.begin(host: resolved.server.host, credential: resolved.credential))
        }

        failure = nil
        isInputOpen = false
        hasEnded = false
        bufferFill = 1
        length = nil
        isTimeTrusted = false
        lastUntrustedTime = nil
        pendingSeek = nil
        isNativeLoop = false
        defaultTrackIDs = []
        isTrackSelectionManual = false
        pendingSlave = nil
        slaveTitles = [:]
        state = PlaybackState(status: .opening, volume: state.volume, videoScaling: state.videoScaling)

        // Swapping the media under a playing player sends no state change at all: no stop, no opening.
        // The player just stays playing, so only the old state tells us which events to expect.
        vlcState = player.state == .playing ? .playing : .opening
        player.rate = 1
        player.media = media
        // libvlc only opens a media when asked to play; there is no separate prepare step.
        player.play()
        publish()
    }

    public func play() {
        guard player.media != nil, !isClosed else { return }
        if hasEnded {
            hasEnded = false
            isInputOpen = false
        }
        player.play()
    }

    public func pause() {
        guard player.canPause else { return }
        player.pause()
    }

    public func seek(to position: Duration, precision: SeekPrecision) {
        guard player.media != nil, !isClosed else { return }
        let target = clamped(position)
        state.progress.position = target
        if isSeekableNow {
            // VLCKit's time setter always requests a precise seek; libvlc's fast mode isn't exposed, so `.fast` costs the same.
            player.time = VLCTime(target)
        } else {
            // libvlc drops seeks until the input is open and seekable, so hold the target and apply it once it is.
            pendingSeek = target
            if hasEnded {
                play()
            }
        }
        publish()
    }

    public func seek(by offset: Duration) {
        seek(to: state.progress.position + offset, precision: .fast)
    }

    public func seek(toChapter id: Chapter.ID) {
        guard let chapter = state.chapters.first(where: { $0.id == id }) else { return }
        player.currentChapterIndex = Int32(id)
        state.progress.position = chapter.start
        publish()
    }

    public func stepFrame() {
        guard vlcState == .paused else { return }
        player.gotoNextFrame()
    }

    public func setLoop(_ range: ClosedRange<Duration>?) {
        state.loop = range
        if let range {
            isNativeLoop = player.setABLoopFrom(VLCTime(range.lowerBound), to: VLCTime(range.upperBound))
        } else {
            isNativeLoop = false
            _ = player.resetABLoop()
        }
        publish()
    }

    public func setRate(_ rate: Double) {
        player.rate = Float(rate)
        state.rate = rate
        publish()
    }

    public func setVolume(_ level: Double) {
        let level = min(max(level, 0), 2)
        // libvlc's volume is a percentage; anything above 100 is amplified inside the audio output.
        player.audio?.volume = Int32((level * 100).rounded())
        state.volume = level
        publish()
    }

    public func setVideoScaling(_ scaling: VideoScaling) {
        switch scaling {
        case .fit:
            player.videoAspectRatio = nil
            player.videoFitMode = .smaller
        case .fill:
            player.videoAspectRatio = nil
            player.videoFitMode = .larger
        case .aspect(let width, let height):
            player.videoAspectRatio = "\(width):\(height)"
            player.videoFitMode = .smaller
        }
        state.videoScaling = scaling
        publish()
    }

    public func selectTrack(_ id: MediaTrack.ID) throws(PlaybackError) {
        guard let track = allTracks().first(where: { $0.trackId == id }), let kind = MediaTrack.Kind(track.type) else {
            throw .unknownTrack(id)
        }
        isTrackSelectionManual = true
        track.isSelectedExclusively = true
        // The selection event lands a moment later; show the choice now so a menu doesn't flicker back.
        let sameKind = state.tracks.filter { $0.kind == kind }.map(\.id)
        state.selectedTrackIDs.subtract(sameKind)
        state.selectedTrackIDs.insert(id)
        publish()
    }

    public func deselectTrack(kind: MediaTrack.Kind) {
        isTrackSelectionManual = true
        switch kind {
        case .audio: player.deselectAllAudioTracks()
        case .subtitle: player.deselectAllTextTracks()
        case .video: player.deselectAllVideoTracks()
        }
        state.selectedTrackIDs.subtract(state.tracks.filter { $0.kind == kind }.map(\.id))
        publish()
    }

    public func addSubtitle(from url: URL) throws(PlaybackError) {
        guard player.media != nil else { throw .unreadableSubtitle(url) }
        if url.isFileURL, !FileManager.default.isReadableFile(atPath: url.path(percentEncoded: false)) {
            throw .unreadableSubtitle(url)
        }
        isTrackSelectionManual = true
        let existingIDs = Set(player.textTracks.map(\.trackId))
        guard player.addPlaybackSlave(url, type: .subtitle, enforce: true) == 0 else {
            throw .unreadableSubtitle(url)
        }
        pendingSlave = (url.deletingPathExtension().lastPathComponent, existingIDs)
        // A slave added while paused restarts decoding but leaves the player reporting paused, with no time updates.
        // It's playing either way, so make the state say so.
        if vlcState == .paused {
            player.play()
        }
        refreshTracks()
        publish()
    }

    public func setSubtitleDelay(_ delay: Duration) {
        player.currentVideoSubTitleDelay = Int(delay.microseconds)
        state.subtitleDelay = delay
        publish()
    }

    public func setSubtitleStyle(_ style: SubtitleStyle) {
        player.currentSubTitleFontScale = style.fontScale
    }

    public func captureFrame() async throws(PlaybackError) -> URL {
        // saveVideoSnapshot raises an Objective-C exception without a video output, which Swift can't catch.
        guard player.hasVideoOut, !isClosed else { throw .captureFailed }
        do {
            try FileManager.default.createDirectory(at: captureDirectory, withIntermediateDirectories: true)
        } catch {
            throw .captureFailed
        }
        // libvlc writes its default snapshot format, PNG, whatever the extension says.
        let url = captureDirectory.appending(path: "\(UUID().uuidString).png")
        let id = UUID()
        let result = await withCheckedContinuation { continuation in
            pendingCaptures.append(PendingCapture(id: id, url: url, continuation: continuation))
            player.saveVideoSnapshot(at: url.path(percentEncoded: false), withWidth: 0, andHeight: 0)
            Task {
                try? await Task.sleep(for: .seconds(5))
                self.failCapture(id)
            }
        }
        return try result.get()
    }

    public func close() {
        guard !isClosed else { return }
        isClosed = true
        player.delegate = nil
        // stop is asynchronous in VLCKit 4; the player finishes tearing down when it's released.
        player.stop()
        location?.relinquish()
        location = nil
        endShareLogin()
        bridge.finish()
        failPendingCaptures()
        state = PlaybackState()
        broadcast.send(state)
        broadcast.finish()
    }
}

extension VLCPlaybackEngine {
    /// Creates the engine together with the view VLC renders into. Hand the view to `VideoSurface`.
    /// `servers` and `credentials` let it open `.networkShare` sources; without them, shares fail with `.unknownServer`.
    @MainActor
    public static func makeWithSurface(
        subtitleStyle: SubtitleStyle = SubtitleStyle(),
        servers: (any NetworkServerRepository)? = nil,
        credentials: (any CredentialStore)? = nil
    ) -> (engine: VLCPlaybackEngine, drawable: VideoDrawable) {
        let drawable = VideoDrawable()
        let engine = VLCPlaybackEngine(drawable: drawable, subtitleStyle: subtitleStyle, servers: servers, credentials: credentials)
        return (engine, drawable)
    }
}

private extension VLCPlaybackEngine {
    func resolveShare(for source: MediaSource) async throws(PlaybackError) -> (server: NetworkServer, address: ShareAddress, credential: NetworkCredential?)? {
        guard case .networkShare(let id, let path) = source else { return nil }
        guard let server = try? await servers?.server(withID: id) else { throw .unknownServer(id) }
        let credential = try? await credentials?.credential(for: id)
        return (server, try ShareAddress(server: server, path: path, credential: credential), credential)
    }

    func endShareLogin() {
        guard let share else { return }
        responder.end(share.login)
        self.share = nil
    }

    var isSeekableNow: Bool {
        isInputOpen && (vlcState == .playing || vlcState == .paused) && player.isSeekable
    }

    func handle(_ event: EngineEvent) {
        guard !isClosed else { return }
        switch event {
        case .stateChanged(let newState):
            handleStateChange(newState)
        case .bufferingChanged(let fill):
            // The header calls this a percentage, but this build reports 0...1.
            bufferFill = min(max(fill, 0), 1)
        case .rateChanged(let rate):
            state.rate = rate
        case .lengthChanged(let length):
            self.length = length > .zero ? length : nil
            refreshProgress()
        case .timeChanged:
            let previous = state.progress.position
            refreshProgress()
            // libvlc doesn't always report the cache back at 100% after a stall; time moving forward means it isn't buffering.
            if vlcState == .playing, state.progress.position > previous {
                bufferFill = 1
            }
            enforceLoop()
        case .tracksChanged:
            refreshTracks()
        case .chaptersChanged:
            refreshChapters()
        case .capabilitiesChanged:
            isInputOpen = true
            state.isSeekable = player.isSeekable
            applyPendingSeek()
        case .frameStepped:
            refreshProgress()
        case .frameCaptured:
            completeCapture()
        }
        state.status = status
        publish()
    }

    func handleStateChange(_ newState: VLCMediaPlayerState) {
        vlcState = newState
        switch newState {
        case .playing, .paused:
            isInputOpen = true
            state.isSeekable = player.isSeekable
            refreshTracks()
            refreshChapters()
            applyPendingSeek()
        case .error:
            if let share, responder.wasRejected(share.login) {
                failure = .authenticationRequired(server: share.server)
            } else {
                failure = .playbackFailure(isRemote: location?.isRemote ?? true)
            }
        case .stopped:
            // A stop before the input ever opened is a load that went nowhere, not an ending.
            if isInputOpen, failure == nil {
                // VLCKit 4 has no ended state: reaching the end of the media is a stop nobody asked for.
                hasEnded = true
                if let length {
                    state.progress.position = length
                }
            }
        default:
            break
        }
    }

    var status: PlaybackState.Status {
        if let failure {
            return .failed(failure)
        }
        if hasEnded {
            return .ended
        }
        switch vlcState {
        case .opening:
            return bufferFill < 1 ? .buffering(bufferFill) : .opening
        case .playing:
            return bufferFill < 1 ? .buffering(bufferFill) : .playing
        case .paused:
            return .paused
        case .stopping:
            return state.status
        default:
            return .idle
        }
    }

    func refreshProgress() {
        guard let time = player.time.duration else {
            state.progress.duration = length
            return
        }
        // While an HLS stream opens, VLC reports a time far into the stream (around 1:12:09) with length 0.
        // Only trust the time once the length is known, or once playback moves it forward from the last report.
        if !isTimeTrusted {
            let hasAdvanced = vlcState == .playing && lastUntrustedTime.map { time > $0 } == true
            guard length != nil || hasAdvanced else {
                lastUntrustedTime = time
                state.progress.duration = length
                return
            }
            isTimeTrusted = true
        }
        state.progress = PlaybackProgress(position: time, duration: length)
    }

    func refreshTracks() {
        let addedSlave = selectAddedSlave()
        let tracks = allTracks()
        var selected = Set(tracks.filter(\.isSelected).map(\.trackId))
        if let addedSlave {
            // The selection lands a moment later; show it now, as selectTrack does.
            selected.subtract(player.textTracks.map(\.trackId))
            selected.insert(addedSlave)
        }
        // libvlc doesn't expose the container's default flag, but before anyone picks a track,
        // VLC's own selection is exactly the tracks the container marked as default.
        if !isTrackSelectionManual {
            defaultTrackIDs = selected
        }
        state.tracks = tracks.compactMap { track in
            var mapped = MediaTrack(track, isDefault: defaultTrackIDs.contains(track.trackId))
            if let title = slaveTitles[track.trackId] {
                mapped?.title = title
            }
            return mapped
        }
        state.selectedTrackIDs = selected
        let size = player.videoSize
        state.videoSize = size.width > 0 && size.height > 0 ? VideoSize(width: Int(size.width), height: Int(size.height)) : nil
    }

    // In 4.0.0-a25 addPlaybackSlave's enforce flag doesn't select the new track, and libvlc names it "Track N".
    func selectAddedSlave() -> MediaTrack.ID? {
        guard let pendingSlave, let added = player.textTracks.first(where: { !pendingSlave.existingIDs.contains($0.trackId) }) else {
            return nil
        }
        self.pendingSlave = nil
        slaveTitles[added.trackId] = pendingSlave.title
        added.isSelectedExclusively = true
        return added.trackId
    }

    func refreshChapters() {
        let title = player.currentTitleIndex
        guard title >= 0 else {
            state.chapters = []
            return
        }
        state.chapters = player.chapterDescriptions(ofTitle: title).map(Chapter.init)
    }

    func allTracks() -> [VLCMediaPlayer.Track] {
        player.videoTracks + player.audioTracks + player.textTracks
    }

    func applyPendingSeek() {
        guard let target = pendingSeek, isSeekableNow else { return }
        pendingSeek = nil
        player.time = VLCTime(target)
        state.progress.position = target
    }

    func enforceLoop() {
        guard let loop = state.loop, !isNativeLoop, state.progress.position >= loop.upperBound else { return }
        player.time = VLCTime(loop.lowerBound)
        state.progress.position = loop.lowerBound
    }

    func clamped(_ position: Duration) -> Duration {
        let upper = length ?? position
        return min(max(position, .zero), upper)
    }

    func completeCapture() {
        guard !pendingCaptures.isEmpty else { return }
        let capture = pendingCaptures.removeFirst()
        let exists = FileManager.default.fileExists(atPath: capture.url.path(percentEncoded: false))
        capture.continuation.resume(returning: exists ? .success(capture.url) : .failure(.captureFailed))
    }

    func failCapture(_ id: UUID) {
        guard let index = pendingCaptures.firstIndex(where: { $0.id == id }) else { return }
        pendingCaptures.remove(at: index).continuation.resume(returning: .failure(.captureFailed))
    }

    func failPendingCaptures() {
        for capture in pendingCaptures {
            capture.continuation.resume(returning: .failure(.captureFailed))
        }
        pendingCaptures.removeAll()
    }

    func publish() {
        guard !isClosed else { return }
        broadcast.send(state)
    }
}
