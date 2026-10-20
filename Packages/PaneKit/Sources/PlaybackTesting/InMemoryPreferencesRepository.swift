import Domain

public actor InMemoryPreferencesRepository: PreferencesRepository {
    private var preferences: TrackPreferences

    public init(preferences: TrackPreferences = TrackPreferences()) {
        self.preferences = preferences
    }

    public func trackPreferences() async throws -> TrackPreferences {
        preferences
    }

    public func save(_ preferences: TrackPreferences) async throws {
        self.preferences = preferences
    }
}
