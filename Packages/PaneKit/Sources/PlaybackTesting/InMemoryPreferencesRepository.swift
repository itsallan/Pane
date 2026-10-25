import Domain

public actor InMemoryPreferencesRepository: PreferencesRepository {
    private var preferences: TrackPreferences
    private var playback: PlaybackPreferences
    private var style: SubtitleStyle
    private var isCloudSyncOn: Bool

    public init(
        preferences: TrackPreferences = TrackPreferences(),
        playback: PlaybackPreferences = PlaybackPreferences(),
        style: SubtitleStyle = SubtitleStyle(),
        syncsWithCloud: Bool = false
    ) {
        self.preferences = preferences
        self.playback = playback
        self.style = style
        isCloudSyncOn = syncsWithCloud
    }

    public func trackPreferences() async throws -> TrackPreferences {
        preferences
    }

    public func save(_ preferences: TrackPreferences) async throws {
        self.preferences = preferences
    }

    public func playbackPreferences() async throws -> PlaybackPreferences {
        playback
    }

    public func save(_ preferences: PlaybackPreferences) async throws {
        playback = preferences
    }

    public func subtitleStyle() async throws -> SubtitleStyle {
        style
    }

    public func save(_ style: SubtitleStyle) async throws {
        self.style = style
    }

    public func syncsWithCloud() async -> Bool {
        isCloudSyncOn
    }

    public func setSyncsWithCloud(_ isOn: Bool) async {
        isCloudSyncOn = isOn
    }
}
