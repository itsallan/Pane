public struct PlaybackPreferences: Sendable, Hashable {
    public static let skipIntervals: [Duration] = [.seconds(10), .seconds(15), .seconds(30)]

    public var defaultRate: Double
    public var skipInterval: Duration
    public var resume: ResumeBehavior
    public var usesHardwareDecoding: Bool
    /// Lets volume go past 100%, which libvlc does by amplifying in its audio output.
    public var allowsVolumeBoost: Bool
    public var gestures: GesturePreferences

    public init(
        defaultRate: Double = 1,
        skipInterval: Duration = .seconds(10),
        resume: ResumeBehavior = .always,
        usesHardwareDecoding: Bool = true,
        allowsVolumeBoost: Bool = true,
        gestures: GesturePreferences = GesturePreferences()
    ) {
        self.defaultRate = defaultRate
        self.skipInterval = skipInterval
        self.resume = resume
        self.usesHardwareDecoding = usesHardwareDecoding
        self.allowsVolumeBoost = allowsVolumeBoost
        self.gestures = gestures
    }
}

public enum ResumeBehavior: String, Sendable, Hashable, CaseIterable {
    case always
    /// Starts from the beginning and offers the saved position.
    case ask
    case never
}

public struct GesturePreferences: Sendable, Hashable {
    /// Vertical swipes on the leading and trailing halves.
    public var adjustsBrightnessAndVolume: Bool
    public var doubleTapSeeks: Bool
    public var longPressSpeedsUp: Bool

    public init(adjustsBrightnessAndVolume: Bool = true, doubleTapSeeks: Bool = true, longPressSpeedsUp: Bool = true) {
        self.adjustsBrightnessAndVolume = adjustsBrightnessAndVolume
        self.doubleTapSeeks = doubleTapSeeks
        self.longPressSpeedsUp = longPressSpeedsUp
    }
}
