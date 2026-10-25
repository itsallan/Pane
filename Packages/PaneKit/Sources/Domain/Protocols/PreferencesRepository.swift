public protocol PreferencesRepository: Sendable {
    func trackPreferences() async throws -> TrackPreferences
    func save(_ preferences: TrackPreferences) async throws
    func playbackPreferences() async throws -> PlaybackPreferences
    func save(_ preferences: PlaybackPreferences) async throws
    func subtitleStyle() async throws -> SubtitleStyle
    func save(_ style: SubtitleStyle) async throws
    /// Off by default. Takes effect the next time the library store opens.
    func syncsWithCloud() async -> Bool
    func setSyncsWithCloud(_ isOn: Bool) async
}
