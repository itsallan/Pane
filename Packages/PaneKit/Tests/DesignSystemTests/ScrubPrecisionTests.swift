import DesignSystem
import Testing

struct ScrubPrecisionTests {
    private let precision = ScrubPrecision(finestScale: 0.1, slowSpeed: 100, fastSpeed: 500)

    @Test func slowDragUsesTheFinestScale() {
        #expect(precision.scale(forSpeed: 0) == 0.1)
        #expect(precision.scale(forSpeed: 100) == 0.1)
    }

    @Test func fastDragMapsOneToOne() {
        #expect(precision.scale(forSpeed: 500) == 1)
        #expect(precision.scale(forSpeed: 4000) == 1)
    }

    @Test func scaleInterpolatesBetweenSpeeds() {
        #expect(abs(precision.scale(forSpeed: 300) - 0.55) < 0.0001)
    }

    @Test func directionDoesNotMatter() {
        #expect(precision.scale(forSpeed: -300) == precision.scale(forSpeed: 300))
    }
}
