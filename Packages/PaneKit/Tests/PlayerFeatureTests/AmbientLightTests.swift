import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct AmbientLightTests {
    private let teal = AmbientPalette(swatches: [AmbientPalette.Swatch(red: 0.1, green: 0.6, blue: 0.6)])
    private let black = AmbientPalette(swatches: [AmbientPalette.Swatch(red: 0, green: 0, blue: 0)])

    @Test func samplesUntilCancelled() async {
        let clock = ManualClock()
        let engine = FakePlaybackEngine()
        engine.setAmbientPalette(teal)
        let light = AmbientLight(engine: engine, sleep: { try await clock.sleep(for: $0) })
        let task = Task { await light.run() }

        await eventually { light.palette == teal }
        let orange = AmbientPalette(swatches: [AmbientPalette.Swatch(red: 0.9, green: 0.5, blue: 0.1)])
        engine.setAmbientPalette(orange)
        clock.advance(by: AmbientLight.interval)
        await eventually { light.palette == orange }
        #expect(light.palette == orange)
        task.cancel()
    }

    @Test func keepsTheLastWashThroughABlackFrame() async {
        let clock = ManualClock()
        let engine = FakePlaybackEngine()
        engine.setAmbientPalette(teal)
        let light = AmbientLight(engine: engine, sleep: { try await clock.sleep(for: $0) })
        let task = Task { await light.run() }
        defer { task.cancel() }
        await eventually { light.palette == teal }

        engine.setAmbientPalette(black)
        clock.advance(by: AmbientLight.interval)
        await settle()
        #expect(light.palette == teal)
    }

    @Test func onceStopsAfterTheFirstUsableSample() async {
        let engine = FakePlaybackEngine()
        engine.setAmbientPalette(teal)
        let light = AmbientLight(engine: engine, sleep: { _ in Issue.record("Reduce Motion shouldn't keep sampling") })
        await light.run(once: true)
        #expect(light.palette == teal)
    }

    @Test func paletteAlwaysFillsTheGrid() {
        #expect(teal.swatches.count == AmbientPalette.columns * AmbientPalette.rows)
        #expect(AmbientPalette(swatches: []).swatches.count == AmbientPalette.columns * AmbientPalette.rows)
    }
}
