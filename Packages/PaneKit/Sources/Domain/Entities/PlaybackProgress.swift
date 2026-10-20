public struct PlaybackProgress: Sendable, Hashable {
    public var position: Duration
    /// `nil` while unknown, and for live streams.
    public var duration: Duration?

    public init(position: Duration, duration: Duration?) {
        self.position = position
        self.duration = duration
    }

    public var fractionWatched: Double? {
        guard let duration, duration > .zero else { return nil }
        return min(max(position / duration, 0), 1)
    }
}

extension PlaybackProgress {
    static let minimumResumePosition = Duration.seconds(30)
    static let watchedFraction = 0.95

    var isWatched: Bool {
        guard let fractionWatched else { return false }
        return fractionWatched >= Self.watchedFraction
    }

    var resumePosition: Duration? {
        guard position >= Self.minimumResumePosition, !isWatched else { return nil }
        return position
    }
}
