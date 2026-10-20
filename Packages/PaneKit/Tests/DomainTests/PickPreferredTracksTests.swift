@testable import Domain
import Foundation
import PlaybackTesting
import Testing

struct PickPreferredTracksTests {
    private let englishAudio = MediaTrack(id: "a-en", kind: .audio, language: "eng")
    private let japaneseAudio = MediaTrack(id: "a-ja", kind: .audio, language: "Japanese", isDefault: true)
    private let englishForced = MediaTrack(id: "s-en-forced", kind: .subtitle, language: "en", isForced: true)
    private let englishFull = MediaTrack(id: "s-en", kind: .subtitle, language: "English")
    private let frenchFull = MediaTrack(id: "s-fr", kind: .subtitle, language: "fre")
    private let japaneseForced = MediaTrack(id: "s-ja-forced", kind: .subtitle, language: "jpn", isForced: true)
    private let defaultSubtitle = MediaTrack(id: "s-default", kind: .subtitle, language: "de", isDefault: true)

    private var allTracks: [MediaTrack] {
        [englishAudio, japaneseAudio, englishForced, englishFull, frenchFull, japaneseForced, defaultSubtitle]
    }

    private func pick(
        _ tracks: [MediaTrack]? = nil,
        audio: [String] = [],
        subtitles: [String] = [],
        mode: TrackPreferences.SubtitleMode
    ) -> PickPreferredTracks.Selection {
        let preferences = TrackPreferences(
            audioLanguages: audio.map(Locale.Language.init(identifier:)),
            subtitleLanguages: subtitles.map(Locale.Language.init(identifier:)),
            subtitleMode: mode
        )
        return PickPreferredTracks.selection(from: tracks ?? allTracks, preferences: preferences)
    }

    @Test func audioFollowsPreferenceOrder() {
        #expect(pick(audio: ["fr", "en", "ja"], mode: .off).audio == englishAudio.id)
        #expect(pick(audio: ["ja", "en"], mode: .off).audio == japaneseAudio.id)
    }

    @Test func audioFallsBackToDefaultThenFirst() {
        #expect(pick(audio: ["fr"], mode: .off).audio == japaneseAudio.id)
        let noDefault = [englishAudio, MediaTrack(id: "a-de", kind: .audio, language: "de")]
        #expect(pick(noDefault, audio: ["fr"], mode: .off).audio == englishAudio.id)
    }

    @Test func offShowsOnlyForcedTracksInTheAudioLanguage() {
        #expect(pick(audio: ["en"], subtitles: ["fr"], mode: .off).subtitle == englishForced.id)
        #expect(pick(audio: ["ja"], subtitles: ["fr"], mode: .off).subtitle == japaneseForced.id)
        #expect(pick([englishAudio, frenchFull], audio: ["en"], subtitles: ["fr"], mode: .off).subtitle == nil)
    }

    @Test func autoActsLikeOffWhenAudioMatchesAPreference() {
        #expect(pick(audio: ["en"], subtitles: ["fr"], mode: .auto).subtitle == englishForced.id)
    }

    @Test func autoPicksSubtitlesWhenAudioIsForeign() {
        #expect(pick(audio: ["fr"], subtitles: ["fr", "en"], mode: .auto).subtitle == frenchFull.id)
    }

    @Test func autoPrefersTheFullTrackOverAForcedOne() {
        #expect(pick(audio: ["de"], subtitles: ["en"], mode: .auto).subtitle == englishFull.id)
        let forcedOnly = [japaneseAudio, englishForced]
        #expect(pick(forcedOnly, audio: ["de"], subtitles: ["en"], mode: .auto).subtitle == englishForced.id)
    }

    @Test func autoWithoutAMatchFallsBackToForced() {
        #expect(pick(audio: ["de"], subtitles: ["it"], mode: .auto).subtitle == japaneseForced.id)
    }

    @Test func alwaysUsesPreferenceThenDefaultThenNothing() {
        #expect(pick(audio: ["en"], subtitles: ["fr"], mode: .always).subtitle == frenchFull.id)
        #expect(pick(audio: ["en"], subtitles: ["it"], mode: .always).subtitle == defaultSubtitle.id)
        #expect(pick([englishAudio, frenchFull], audio: ["en"], subtitles: ["it"], mode: .always).subtitle == nil)
    }

    @Test func noTracksSelectsNothing() {
        #expect(pick([], audio: ["en"], subtitles: ["en"], mode: .always) == .init(audio: nil, subtitle: nil))
    }

    @Test(arguments: ["en", "eng", "English", "english", "en-US"])
    func englishAliasesMatch(tag: String) {
        let track = MediaTrack(id: "a", kind: .audio, language: tag)
        #expect(track.matches(Locale.Language(identifier: "en-GB")))
        #expect(!track.matches(Locale.Language(identifier: "fr")))
    }

    @Test(arguments: [("fre", "fr"), ("fra", "fr"), ("Français", "fr"), ("ger", "de"), ("chi", "zh"), ("jpn", "ja")])
    func otherAliasesMatch(tag: String, language: String) {
        let track = MediaTrack(id: "a", kind: .audio, language: tag)
        #expect(track.matches(Locale.Language(identifier: language)))
    }

    @Test(arguments: ["und", "mul", "", "Klingonish", "xx"])
    func unknownTagsNeverMatch(tag: String) {
        #expect(Locale.Language(trackTag: tag) == nil)
    }

    @Test func appliesTheSelectionToTheEngine() async throws {
        let engine = FakePlaybackEngine(state: PlaybackState(tracks: allTracks, selectedTrackIDs: [japaneseAudio.id, defaultSubtitle.id]))
        let preferences = InMemoryPreferencesRepository(preferences: TrackPreferences(audioLanguages: [Locale.Language(identifier: "en")], subtitleMode: .auto))
        try await PickPreferredTracks(engine: engine, preferences: preferences)(for: engine.state)
        #expect(engine.calls == [.selectTrack(englishAudio.id), .selectTrack(englishForced.id)])
        #expect(engine.state.selectedTrackIDs == [englishAudio.id, englishForced.id])
    }

    @Test func turnsOffSubtitlesTheContainerEnabled() async throws {
        let tracks = [englishAudio, defaultSubtitle]
        let engine = FakePlaybackEngine(state: PlaybackState(tracks: tracks, selectedTrackIDs: [englishAudio.id, defaultSubtitle.id]))
        let preferences = InMemoryPreferencesRepository(preferences: TrackPreferences(subtitleMode: .off))
        try await PickPreferredTracks(engine: engine, preferences: preferences)(for: engine.state)
        #expect(engine.calls == [.deselectTrack(.subtitle)])
    }

    @Test func neverOverridesAManualPick() async throws {
        let engine = FakePlaybackEngine(state: PlaybackState(tracks: allTracks, selectedTrackIDs: [japaneseAudio.id, frenchFull.id]))
        let preferences = InMemoryPreferencesRepository(preferences: TrackPreferences(audioLanguages: [Locale.Language(identifier: "en")], subtitleMode: .off))
        try await PickPreferredTracks(engine: engine, preferences: preferences)(for: engine.state, keeping: [.audio, .subtitle])
        #expect(engine.calls.isEmpty)

        try await PickPreferredTracks(engine: engine, preferences: preferences)(for: engine.state, keeping: [.subtitle])
        #expect(engine.calls == [.selectTrack(englishAudio.id)])
        #expect(engine.state.selectedTrackIDs.contains(frenchFull.id))
    }
}
