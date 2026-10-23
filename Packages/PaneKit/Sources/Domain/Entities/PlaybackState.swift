public struct PlaybackState: Sendable, Equatable {
    public enum Status: Sendable, Equatable {
        case idle
        case opening
        case buffering(Double)
        case playing
        case paused
        case ended
        case failed(PlaybackError)
    }

    public var status: Status
    public var progress: PlaybackProgress
    public var rate: Double
    public var volume: Double
    public var videoScaling: VideoScaling
    public var tracks: [MediaTrack]
    public var selectedTrackIDs: Set<MediaTrack.ID>
    public var chapters: [Chapter]
    public var loop: ClosedRange<Duration>?
    public var subtitleDelay: Duration
    public var isSeekable: Bool
    public var videoSize: VideoSize?
    /// The platform and the current video output can show this media in Picture in Picture.
    public var isPictureInPictureSupported: Bool
    public var isPictureInPictureActive: Bool

    public init(
        status: Status = .idle,
        progress: PlaybackProgress = PlaybackProgress(position: .zero, duration: nil),
        rate: Double = 1,
        volume: Double = 1,
        videoScaling: VideoScaling = .fit,
        tracks: [MediaTrack] = [],
        selectedTrackIDs: Set<MediaTrack.ID> = [],
        chapters: [Chapter] = [],
        loop: ClosedRange<Duration>? = nil,
        subtitleDelay: Duration = .zero,
        isSeekable: Bool = false,
        videoSize: VideoSize? = nil,
        isPictureInPictureSupported: Bool = false,
        isPictureInPictureActive: Bool = false
    ) {
        self.status = status
        self.progress = progress
        self.rate = rate
        self.volume = volume
        self.videoScaling = videoScaling
        self.tracks = tracks
        self.selectedTrackIDs = selectedTrackIDs
        self.chapters = chapters
        self.loop = loop
        self.subtitleDelay = subtitleDelay
        self.isSeekable = isSeekable
        self.videoSize = videoSize
        self.isPictureInPictureSupported = isPictureInPictureSupported
        self.isPictureInPictureActive = isPictureInPictureActive
    }

    public func selectedTrack(of kind: MediaTrack.Kind) -> MediaTrack? {
        tracks.first { $0.kind == kind && selectedTrackIDs.contains($0.id) }
    }
}
