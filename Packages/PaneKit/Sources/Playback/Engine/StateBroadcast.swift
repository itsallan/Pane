import Domain
import Foundation
import Synchronization

// A Mutex rather than actor state because `states()` is synchronous and must register the subscriber before it returns.
final class StateBroadcast: Sendable {
    private struct Storage {
        var state = PlaybackState()
        var subscribers: [UUID: AsyncStream<PlaybackState>.Continuation] = [:]
    }

    private let storage = Mutex(Storage())

    func subscribe() -> AsyncStream<PlaybackState> {
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

    func send(_ state: PlaybackState) {
        storage.withLock { storage in
            guard storage.state != state else { return }
            storage.state = state
            for subscriber in storage.subscribers.values {
                subscriber.yield(state)
            }
        }
    }

    func finish() {
        let subscribers = storage.withLock { storage in
            defer { storage.subscribers.removeAll() }
            return Array(storage.subscribers.values)
        }
        for subscriber in subscribers {
            subscriber.finish()
        }
    }
}
