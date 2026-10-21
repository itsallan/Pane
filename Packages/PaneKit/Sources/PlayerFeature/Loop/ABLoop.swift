import Domain
import Foundation
import Observation

/// Marks A, then B, then clears. The looping itself happens in the engine, which doesn't overshoot B by a tick.
@MainActor
@Observable
public final class ABLoop {
    /// Shorter than this and the loop is mostly seeking.
    static let minimumLength = Duration.seconds(1)

    public private(set) var start: Duration?
    public private(set) var range: ClosedRange<Duration>?

    @ObservationIgnored var currentPosition: () -> Duration = { .zero }

    private let engine: any PlaybackEngine

    init(engine: any PlaybackEngine) {
        self.engine = engine
    }

    public func mark() {
        if range != nil {
            clear()
            return
        }
        let position = currentPosition()
        guard let start else {
            self.start = position
            return
        }
        // Marking B before A is taken as the same two points the other way round.
        let range = min(start, position)...max(start, position)
        guard range.upperBound - range.lowerBound >= Self.minimumLength else { return }
        self.start = nil
        self.range = range
        Task { [engine] in await engine.setLoop(range) }
    }

    public func clear() {
        start = nil
        guard range != nil else { return }
        range = nil
        Task { [engine] in await engine.setLoop(nil) }
    }

    func update(from state: PlaybackState) {
        if range != state.loop {
            range = state.loop
        }
    }
}
