import Domain

public actor InMemoryPreferencesRepository: PreferencesRepository {
    private var preferences: TrackPreferences
    private var style: SubtitleStyle

    public init(preferences: TrackPreferences = TrackPreferences(), style: SubtitleStyle = SubtitleStyle()) {
        self.preferences = preferences
        self.style = style
    }

    public func trackPreferences() async throws -> TrackPreferences {
        preferences
    }

    public func save(_ preferences: TrackPreferences) async throws {
        self.preferences = preferences
    }

    public func subtitleStyle() async throws -> SubtitleStyle {
        style
    }

    public func save(_ style: SubtitleStyle) async throws {
        self.style = style
    }
}
