import Synchronization

/// A clock that only moves when `advance(by:)` is called. Sleepers resume once their deadline passes.
public final class ManualClock: Clock {
    public struct Instant: InstantProtocol {
        public var offset: Duration

        public init(offset: Duration) {
            self.offset = offset
        }

        public func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        public func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        public static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private struct Sleeper {
        var deadline: Instant
        var continuation: CheckedContinuation<Void, any Error>
    }

    private struct Storage {
        var now = Instant(offset: .zero)
        var sleepers: [UInt64: Sleeper] = [:]
        var nextID: UInt64 = 0
    }

    private let storage = Mutex(Storage())

    public init() {}

    public var now: Instant { storage.withLock { $0.now } }
    public var minimumResolution: Duration { .zero }

    public func advance(by duration: Duration) {
        let due = storage.withLock { storage in
            storage.now = storage.now.advanced(by: duration)
            let now = storage.now
            let due = storage.sleepers.filter { $0.value.deadline <= now }
            for id in due.keys {
                storage.sleepers[id] = nil
            }
            return due.values.map(\.continuation)
        }
        for continuation in due {
            continuation.resume()
        }
    }

    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        let id = storage.withLock { storage in
            defer { storage.nextID += 1 }
            return storage.nextID
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let isDue = storage.withLock { storage -> Bool? in
                    guard !Task.isCancelled else { return false }
                    guard deadline > storage.now else { return true }
                    storage.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return nil
                }
                switch isDue {
                case true: continuation.resume()
                case false: continuation.resume(throwing: CancellationError())
                case nil: break
                }
            }
        } onCancel: {
            let sleeper = storage.withLock { $0.sleepers.removeValue(forKey: id) }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }
}
