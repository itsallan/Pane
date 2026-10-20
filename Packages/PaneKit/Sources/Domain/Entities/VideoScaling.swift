public enum VideoScaling: Sendable, Hashable {
    case fit
    case fill
    case aspect(width: Int, height: Int)
}

public enum SeekPrecision: Sendable, Hashable {
    /// Lands on the nearest keyframe; cheap enough for scrubbing.
    case fast
    case exact
}

public struct VideoSize: Sendable, Hashable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}
