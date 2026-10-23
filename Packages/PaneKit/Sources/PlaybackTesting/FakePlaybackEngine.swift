import Domain
import Foundation
import Synchronization

/// Records every call and applies it to an in-memory state, so tests can assert on calls and script exact state sequences with `send(_:)`.
/// A class with a `Mutex` rather than an actor because `states()` is synchronous and has to register the subscriber before it returns.
public final class FakePlaybackEngine: PlaybackEngine {
    public enum Call: Sendable, Hashable {
        case load(MediaSource)
        case play
        case pause
        case seek(to: Duration, precision: SeekPrecision)
        case seekBy(Duration)
        case seekToChapter(Chapter.ID)
        case stepFrame
        case setLoop(ClosedRange<Duration>?)
        case setRate(Double)
        case setVolume(Double)
        case setVideoScaling(VideoScaling)
        case selectTrack(MediaTrack.ID)
        case deselectTrack(MediaTrack.Kind)
        case addSubtitle(URL)
        case setSubtitleDelay(Duration)
        case setSubtitleStyle(SubtitleStyle)
        case setPictureInPicture(Bool)
        case captureFrame
        case close
    }

    public struct Failures: Sendable {
        public var load: PlaybackError?
        public var addSubtitle: PlaybackError?
        public var captureFrame: PlaybackError?

        public init(load: PlaybackError? = nil, addSubtitle: PlaybackError? = nil, captureFrame: PlaybackError? = nil) {
            self.load = load
            self.addSubtitle = addSubtitle
            self.captureFrame = captureFrame
        }
    }

    private struct Storage {
        var state: PlaybackState
        var calls: [Call] = []
        var failures: Failures
        var stateOnLoad: PlaybackState?
        var subscribers: [UUID: AsyncStream<PlaybackState>.Continuation] = [:]
    }

    private let storage: Mutex<Storage>
    private let capturedFrameURL: URL
    private let landsSeeks: Bool

    /// `stateOnLoad` replaces the state when `load` succeeds, which is how a test makes tracks and chapters appear.
    /// With `landsSeeks` off, seeks are only recorded, so a test can script the stale times VLC reports before one lands.
    public init(
        state: PlaybackState = PlaybackState(),
        stateOnLoad: PlaybackState? = nil,
        failures: Failures = Failures(),
        landsSeeks: Bool = true,
        capturedFrameURL: URL = URL(filePath: "/tmp/pane-fake-frame.jpg")
    ) {
        storage = Mutex(Storage(state: state, failures: failures, stateOnLoad: stateOnLoad))
        self.landsSeeks = landsSeeks
        self.capturedFrameURL = capturedFrameURL
    }

    public var calls: [Call] { storage.withLock { $0.calls } }
    public var state: PlaybackState { storage.withLock { $0.state } }

    public func setFailures(_ failures: Failures) {
        storage.withLock { $0.failures = failures }
    }

    public func send(_ state: PlaybackState) {
        update { $0 = state }
    }

    public func update(_ change: (inout PlaybackState) -> Void) {
        storage.withLock { storage in
            change(&storage.state)
            for subscriber in storage.subscribers.values {
                subscriber.yield(storage.state)
            }
        }
    }

    public func states() -> AsyncStream<PlaybackState> {
        let (stream, continuation) = AsyncStream.makeStream(of: PlaybackState.self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            self?.storage.withLock { _ = $0.subscribers.removeValue(forKey: id) }
        }
        storage.withLock { storage in
            storage.subscribers[id] = continuation
            continuation.yield(storage.state)
        }
        return stream
    }

    public func load(_ source: MediaSource) async throws(PlaybackError) {
        let failure = storage.withLock { storage in
            storage.calls.append(.load(source))
            return storage.failures.load
        }
        if let failure {
            throw failure
        }
        let loaded = storage.withLock { $0.stateOnLoad }
        update { state in
            state = loaded ?? state
            if loaded == nil {
                state.status = .opening
            }
        }
    }

    public func play() async {
        record(.play) { $0.status = .playing }
    }

    public func pause() async {
        record(.pause) { $0.status = .paused }
    }

    public func seek(to position: Duration, precision: SeekPrecision) async {
        record(.seek(to: position, precision: precision)) { state in
            guard landsSeeks else { return }
            state.progress.position = state.clamped(position)
        }
    }

    public func seek(by offset: Duration) async {
        record(.seekBy(offset)) { state in
            guard landsSeeks else { return }
            state.progress.position = state.clamped(state.progress.position + offset)
        }
    }

    public func seek(toChapter id: Chapter.ID) async {
        record(.seekToChapter(id)) { state in
            guard let chapter = state.chapters.first(where: { $0.id == id }) else { return }
            state.progress.position = chapter.start
        }
    }

    public func stepFrame() async {
        record(.stepFrame) { state in
            guard state.status == .paused else { return }
            state.progress.position = state.clamped(state.progress.position + .milliseconds(40))
        }
    }

    public func setLoop(_ range: ClosedRange<Duration>?) async {
        record(.setLoop(range)) { $0.loop = range }
    }

    public func setRate(_ rate: Double) async {
        record(.setRate(rate)) { $0.rate = rate }
    }

    public func setVolume(_ level: Double) async {
        record(.setVolume(level)) { $0.volume = min(max(level, 0), 2) }
    }

    public func setVideoScaling(_ scaling: VideoScaling) async {
        record(.setVideoScaling(scaling)) { $0.videoScaling = scaling }
    }

    public func selectTrack(_ id: MediaTrack.ID) async throws(PlaybackError) {
        let track = storage.withLock { storage in
            storage.calls.append(.selectTrack(id))
            return storage.state.tracks.first { $0.id == id }
        }
        guard let track else { throw .unknownTrack(id) }
        update { state in
            let sameKind = state.tracks.filter { $0.kind == track.kind }.map(\.id)
            state.selectedTrackIDs.subtract(sameKind)
            state.selectedTrackIDs.insert(id)
        }
    }

    public func deselectTrack(kind: MediaTrack.Kind) async {
        record(.deselectTrack(kind)) { state in
            let ids = state.tracks.filter { $0.kind == kind }.map(\.id)
            state.selectedTrackIDs.subtract(ids)
        }
    }

    public func addSubtitle(from url: URL) async throws(PlaybackError) {
        let failure = storage.withLock { storage in
            storage.calls.append(.addSubtitle(url))
            return storage.failures.addSubtitle
        }
        if let failure {
            throw failure
        }
        update { state in
            let track = MediaTrack(id: "subtitle/\(url.lastPathComponent)", kind: .subtitle, title: url.lastPathComponent)
            state.tracks.append(track)
            state.selectedTrackIDs.subtract(state.tracks.filter { $0.kind == .subtitle }.map(\.id))
            state.selectedTrackIDs.insert(track.id)
        }
    }

    public func setSubtitleDelay(_ delay: Duration) async {
        record(.setSubtitleDelay(delay)) { $0.subtitleDelay = delay }
    }

    public func setSubtitleStyle(_ style: SubtitleStyle) async {
        record(.setSubtitleStyle(style)) { _ in }
    }

    public func setPictureInPicture(_ isActive: Bool) async {
        record(.setPictureInPicture(isActive)) { state in
            guard state.isPictureInPictureSupported else { return }
            state.isPictureInPictureActive = isActive
        }
    }

    public func captureFrame() async throws(PlaybackError) -> URL {
        let failure = storage.withLock { storage in
            storage.calls.append(.captureFrame)
            return storage.failures.captureFrame
        }
        if let failure {
            throw failure
        }
        return capturedFrameURL
    }

    public func close() async {
        record(.close) { $0 = PlaybackState() }
    }

    private func record(_ call: Call, change: (inout PlaybackState) -> Void) {
        storage.withLock { $0.calls.append(call) }
        update(change)
    }
}

private extension PlaybackState {
    func clamped(_ position: Duration) -> Duration {
        let upper = progress.duration ?? position
        return min(max(position, .zero), upper)
    }
}
