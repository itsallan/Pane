/// The average colors of a frame on a coarse grid, row by row from the top leading cell.
public struct AmbientPalette: Sendable, Hashable {
    public struct Swatch: Sendable, Hashable {
        public var red: Double
        public var green: Double
        public var blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    public static let columns = 3
    public static let rows = 3

    public var swatches: [Swatch]

    /// Pads or trims to `columns * rows`, repeating the last swatch, so callers can index the grid freely.
    public init(swatches: [Swatch]) {
        let count = Self.columns * Self.rows
        let filler = swatches.last ?? Swatch(red: 0, green: 0, blue: 0)
        self.swatches = Array((swatches + Array(repeating: filler, count: count)).prefix(count))
    }
}
