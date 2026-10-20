public protocol PreferencesRepository: Sendable {
    func trackPreferences() async throws -> TrackPreferences
    func save(_ preferences: TrackPreferences) async throws
}
