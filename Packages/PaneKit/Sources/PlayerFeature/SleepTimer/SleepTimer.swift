import Domain
import Foundation
import Observation

/// Pauses after a number of minutes, or marks the end of the current video as the place to stop.
@MainActor
@Observable
public final class SleepTimer {
    public enum Setting: Hashable, Sendable {
        case minutes(Int)
        case endOfItem
    }

    public static let presets = [15, 30, 45, 60, 90]

    public var setting: Setting? {
        didSet { schedule() }
    }
    /// When a minutes timer will fire, for the countdown.
    public private(set) var fireDate: Date?
    public private(set) var hasFired = false

    private let engine: any PlaybackEngine
    private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var countdown: Task<Void, Never>?

    init(engine: any PlaybackEngine, sleep: @escaping @Sendable (Duration) async throws -> Void) {
        self.engine = engine
        self.sleep = sleep
    }

    isolated deinit {
        countdown?.cancel()
    }

    /// With no next item to stop before yet, ending is already the stop; this just records that the timer did its job.
    func itemDidEnd() {
        guard setting == .endOfItem else { return }
        fire()
    }

    private func schedule() {
        countdown?.cancel()
        countdown = nil
        fireDate = nil
        guard case .minutes(let minutes) = setting else { return }
        hasFired = false
        let duration = Duration.seconds(minutes * 60)
        fireDate = .now.addingTimeInterval(TimeInterval(minutes * 60))
        countdown = Task { [weak self, sleep] in
            do {
                try await sleep(duration)
            } catch {
                return
            }
            self?.fire()
        }
    }

    private func fire() {
        countdown = nil
        fireDate = nil
        setting = nil
        hasFired = true
        Task { [engine] in await engine.pause() }
    }
}
