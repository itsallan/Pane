import Domain
import Foundation
import Observation

/// Saves the frame on screen to Photos and reports how it went for a moment.
@MainActor
@Observable
public final class FrameSnapshot {
    public enum Outcome: Equatable {
        case saved
        case accessDenied
        case failed
    }

    static let outcomeDuration = Duration.seconds(2)

    public private(set) var isSaving = false
    public private(set) var outcome: Outcome?

    private let engine: any PlaybackEngine
    private let photoLibrary: (any PhotoLibrary)?
    private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var dismissal: Task<Void, Never>?

    init(engine: any PlaybackEngine, photoLibrary: (any PhotoLibrary)?, sleep: @escaping @Sendable (Duration) async throws -> Void) {
        self.engine = engine
        self.photoLibrary = photoLibrary
        self.sleep = sleep
    }

    public var isAvailable: Bool { photoLibrary != nil }

    public func capture() async {
        guard let photoLibrary, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let frame = try await engine.captureFrame()
            try await photoLibrary.addImage(at: frame)
            show(.saved)
        } catch let error as PhotoLibraryError where error == .accessDenied {
            show(.accessDenied)
        } catch {
            show(.failed)
        }
    }

    private func show(_ outcome: Outcome) {
        self.outcome = outcome
        dismissal?.cancel()
        dismissal = Task { [weak self, sleep] in
            do {
                try await sleep(Self.outcomeDuration)
            } catch {
                return
            }
            self?.outcome = nil
        }
    }
}
