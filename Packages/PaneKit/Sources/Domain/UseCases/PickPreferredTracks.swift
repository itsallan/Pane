import Foundation

public struct PickPreferredTracks: Sendable {
    private let engine: any PlaybackEngine
    private let preferences: any PreferencesRepository

    public init(engine: any PlaybackEngine, preferences: any PreferencesRepository) {
        self.engine = engine
        self.preferences = preferences
    }

    /// Run once per load, when tracks first appear. Kinds in `manualKinds` were picked by the user this session
    /// and are left alone.
    public func callAsFunction(for state: PlaybackState, keeping manualKinds: Set<MediaTrack.Kind> = []) async throws(PlaybackError) {
        let preferences = (try? await preferences.trackPreferences()) ?? TrackPreferences()
        let selection = Self.selection(from: state.tracks, preferences: preferences)

        if !manualKinds.contains(.audio), let audio = selection.audio, !state.selectedTrackIDs.contains(audio) {
            try await engine.selectTrack(audio)
        }
        guard !manualKinds.contains(.subtitle) else { return }
        if let subtitle = selection.subtitle {
            if !state.selectedTrackIDs.contains(subtitle) {
                try await engine.selectTrack(subtitle)
            }
        } else if state.selectedTrack(of: .subtitle) != nil {
            await engine.deselectTrack(kind: .subtitle)
        }
    }
}

extension PickPreferredTracks {
    struct Selection: Hashable {
        var audio: MediaTrack.ID?
        var subtitle: MediaTrack.ID?
    }

    static func selection(from tracks: [MediaTrack], preferences: TrackPreferences) -> Selection {
        let audioTracks = tracks.filter { $0.kind == .audio }
        let subtitles = tracks.filter { $0.kind == .subtitle }

        let preferredAudio = firstMatch(in: audioTracks, languages: preferences.audioLanguages)
        let audio = preferredAudio ?? audioTracks.first(where: \.isDefault) ?? audioTracks.first
        let forced = audio.flatMap { audio in subtitles.first { $0.isForced && $0.sharesLanguage(with: audio) } }

        let subtitle: MediaTrack? = switch preferences.subtitleMode {
        case .off:
            forced
        case .auto where preferredAudio != nil:
            forced
        case .auto:
            firstMatch(in: subtitles, languages: preferences.subtitleLanguages) ?? forced
        case .always:
            firstMatch(in: subtitles, languages: preferences.subtitleLanguages)
                ?? subtitles.first(where: \.isDefault)
                ?? forced
        }
        return Selection(audio: audio?.id, subtitle: subtitle?.id)
    }

    // A forced track only covers foreign dialogue, so someone who asked for subtitles wants the full one when it exists.
    private static func firstMatch(in tracks: [MediaTrack], languages: [Locale.Language]) -> MediaTrack? {
        for language in languages {
            let matching = tracks.filter { $0.matches(language) }
            if let track = matching.first(where: { !$0.isForced }) ?? matching.first {
                return track
            }
        }
        return nil
    }
}
