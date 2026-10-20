/// Maps finger speed to how much of a drag reaches the playhead, so a slow drag seeks finely and a flick covers the timeline.
public struct ScrubPrecision: Sendable, Hashable {
    public var finestScale: Double
    /// Points per second at or below which the finest scale applies.
    public var slowSpeed: Double
    /// Points per second at or above which the drag maps one to one.
    public var fastSpeed: Double

    public init(finestScale: Double = 0.1, slowSpeed: Double = 60, fastSpeed: Double = 700) {
        self.finestScale = finestScale
        self.slowSpeed = slowSpeed
        self.fastSpeed = fastSpeed
    }

    public static let standard = ScrubPrecision()

    public func scale(forSpeed speed: Double) -> Double {
        guard fastSpeed > slowSpeed else { return 1 }
        let progress = min(max((abs(speed) - slowSpeed) / (fastSpeed - slowSpeed), 0), 1)
        return finestScale + (1 - finestScale) * progress
    }
}
