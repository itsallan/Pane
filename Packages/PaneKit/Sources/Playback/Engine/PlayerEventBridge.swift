import Foundation
@preconcurrency import VLCKit

// With the default events configuration, VLCKit calls the delegate synchronously on libvlc's event thread,
// except time changes, which come from an NSTimer on the main run loop. Each callback only yields a value;
// reading the player here would race with libvlc.
final class PlayerEventBridge: NSObject, Sendable {
    let events: AsyncStream<EngineEvent>
    private let continuation: AsyncStream<EngineEvent>.Continuation

    override init() {
        (events, continuation) = AsyncStream.makeStream(of: EngineEvent.self)
        super.init()
    }

    func yield(_ event: EngineEvent) {
        continuation.yield(event)
    }

    func finish() {
        continuation.finish()
    }
}

extension PlayerEventBridge: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        yield(.stateChanged(newState))
    }

    func mediaPlayerBufferingChanged(_ progress: Float) {
        yield(.bufferingChanged(Double(progress)))
    }

    func mediaPlayerRateChanged(_ rate: Float) {
        yield(.rateChanged(Double(rate)))
    }

    // VLCKit converts libvlc's microseconds to milliseconds before calling this.
    func mediaPlayerLengthChanged(_ length: Int64) {
        yield(.lengthChanged(.milliseconds(length)))
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        yield(.timeChanged)
    }

    func mediaPlayerTrackAdded(_ trackId: String, with trackType: VLCMedia.TrackType) {
        yield(.tracksChanged)
    }

    func mediaPlayerTrackRemoved(_ trackId: String, with trackType: VLCMedia.TrackType) {
        yield(.tracksChanged)
    }

    func mediaPlayerTrackUpdated(_ trackId: String, with trackType: VLCMedia.TrackType) {
        yield(.tracksChanged)
    }

    func mediaPlayerTrackSelected(_ trackType: VLCMedia.TrackType, selectedId: String, unselectedId: String) {
        yield(.tracksChanged)
    }

    func mediaPlayerTitleListChanged(_ aNotification: Notification) {
        yield(.chaptersChanged)
    }

    func mediaPlayerTitleSelectionChanged(_ aNotification: Notification) {
        yield(.chaptersChanged)
    }

    // The notification carries no path; libvlc writes to the path we passed to saveVideoSnapshotAt.
    func mediaPlayerSnapshot(_ aNotification: Notification) {
        yield(.frameCaptured)
    }

    func mediaPlayer(_ player: VLCMediaPlayer, nextFrameSteppedWith result: VLCMediaPlayerFrameStepResult) {
        yield(.frameStepped)
    }
}
