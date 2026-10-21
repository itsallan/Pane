public protocol PreferencesRepository: Sendable {
    func trackPreferences() async throws -> TrackPreferences
    func save(_ preferences: TrackPreferences) async throws
    func subtitleStyle() async throws -> SubtitleStyle
    func save(_ style: SubtitleStyle) async throws
}
