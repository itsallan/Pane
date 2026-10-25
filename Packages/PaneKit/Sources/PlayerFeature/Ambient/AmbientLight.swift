import Domain
import Foundation
import Observation

/// The colors of the frame on screen, sampled about once a second for the backdrop behind the video.
@MainActor
@Observable
public final class AmbientLight {
    static let interval = Duration.seconds(1)
    // A dark or failed sample shouldn't wipe a good wash, so the previous palette stays until a better one arrives.
    nonisolated static let minimumBrightness = 0.04

    public private(set) var palette: AmbientPalette?

    private let engine: any PlaybackEngine
    private let sleep: @Sendable (Duration) async throws -> Void

    init(engine: any PlaybackEngine, sleep: @escaping @Sendable (Duration) async throws -> Void) {
        self.engine = engine
        self.sleep = sleep
    }

    /// Samples until cancelled. With `once`, for Reduce Motion, it stops at the first usable palette.
    public func run(once: Bool = false) async {
        if once, palette != nil { return }
        while !Task.isCancelled {
            if let sampled = try? await engine.sampleAmbientPalette(), !Task.isCancelled, sampled.isUsable {
                palette = sampled
                if once { return }
            }
            do {
                try await sleep(Self.interval)
            } catch {
                return
            }
        }
    }
}

private extension AmbientPalette {
    var isUsable: Bool {
        swatches.contains { max($0.red, $0.green, $0.blue) > AmbientLight.minimumBrightness }
    }
}
