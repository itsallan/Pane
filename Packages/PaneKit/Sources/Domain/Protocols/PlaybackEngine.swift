import Foundation

/// `states()` returns a new stream per call. Each subscriber gets the current state immediately, then every change,
/// buffered as `.bufferingNewest(1)`. Cancelling the consuming task unsubscribes.
public protocol PlaybackEngine: Sendable {
    func states() -> AsyncStream<PlaybackState>

    func load(_ source: MediaSource) async throws(PlaybackError)
    func play() async
    func pause() async
    func seek(to position: Duration, precision: SeekPrecision) async
    func seek(by offset: Duration) async
    func seek(toChapter id: Chapter.ID) async
    /// Steps forward one frame. Only valid while paused.
    func stepFrame() async
    /// An A-B loop, or `nil` to clear it.
    func setLoop(_ range: ClosedRange<Duration>?) async
    func setRate(_ rate: Double) async
    /// `0...2`; above 1 boosts inside the audio output.
    func setVolume(_ level: Double) async
    func setVideoScaling(_ scaling: VideoScaling) async
    func selectTrack(_ id: MediaTrack.ID) async throws(PlaybackError)
    func deselectTrack(kind: MediaTrack.Kind) async
    func addSubtitle(from url: URL) async throws(PlaybackError)
    func setSubtitleDelay(_ delay: Duration) async
    /// The size changes at once; background and position may only take effect from the next engine.
    func setSubtitleStyle(_ style: SubtitleStyle) async
    /// Returns a file URL in Caches.
    func captureFrame() async throws(PlaybackError) -> URL
    func close() async
}
