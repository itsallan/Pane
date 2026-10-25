import Foundation

extension Double {
    /// A playback rate as people read it: "1×", "1.25×".
    public var rateLabel: String {
        formatted(.number.precision(.fractionLength(0...2))) + "×"
    }
}
