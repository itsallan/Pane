#if os(iOS)
import Foundation
import Synchronization
@preconcurrency import VLCKit

/// What Picture in Picture asks about the media. AVKit asks synchronously from the main thread,
/// and the engine lives on its own queue, so the engine keeps a copy here instead of being asked.
final class PictureInPictureMedia: NSObject, Sendable {
    enum Command: Sendable {
        case play
        case pause
        case seek(by: Duration)
    }

    struct Snapshot: Equatable {
        var length: Duration?
        var time = Duration.zero
        var isSeekable = false
        var isPlaying = false
    }

    private let snapshot = Mutex(Snapshot())
    private let perform: Mutex<(@Sendable (Command) -> Void)?> = Mutex(nil)

    /// Returns whether anything changed, so the caller knows to have the window refresh.
    func update(_ new: Snapshot) -> Bool {
        snapshot.withLock { current in
            // Time moves on every tick; AVKit extrapolates it, so only a change in what it can't predict matters.
            let changed = current.length != new.length || current.isSeekable != new.isSeekable || current.isPlaying != new.isPlaying
            current = new
            return changed
        }
    }

    func onCommand(_ handler: @escaping @Sendable (Command) -> Void) {
        perform.withLock { $0 = handler }
    }

    private func send(_ command: Command) {
        perform.withLock { $0 }?(command)
    }
}

extension PictureInPictureMedia: VLCPictureInPictureMediaControlling {
    func play() {
        send(.play)
    }

    func pause() {
        send(.pause)
    }

    // The completion only tells AVKit to read the time again. The seek lands a moment later on the engine's queue
    // and the snapshot follows, so there's nothing to wait for.
    func seek(by offset: Int64, completion: @escaping () -> Void) {
        send(.seek(by: .milliseconds(offset)))
        completion()
    }

    func mediaLength() -> Int64 {
        snapshot.withLock { $0.length.map(\.milliseconds) ?? 0 }
    }

    func mediaTime() -> Int64 {
        snapshot.withLock { $0.time.milliseconds }
    }

    func isMediaSeekable() -> Bool {
        snapshot.withLock { $0.isSeekable }
    }

    func isMediaPlaying() -> Bool {
        snapshot.withLock { $0.isPlaying }
    }
}
#endif
