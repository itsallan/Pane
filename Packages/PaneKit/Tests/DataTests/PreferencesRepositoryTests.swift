import Data
import Domain
import Foundation
import Testing

struct PreferencesRepositoryTests {
    @Test func subtitleStyleRoundTrips() async throws {
        let suite = "io.pane.player.tests.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsPreferencesRepository(suiteName: suite)
        #expect(try await repository.subtitleStyle() == SubtitleStyle())

        let style = SubtitleStyle(size: .extraLarge, background: .translucent, position: .high)
        try await repository.save(style)

        #expect(try await repository.subtitleStyle() == style)
    }
}

struct PlaybackPreferencesRepositoryTests {
    @Test func defaultsUntilSaved() async throws {
        let suite = "io.pane.player.tests.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsPreferencesRepository(suiteName: suite)
        #expect(try await repository.playbackPreferences() == PlaybackPreferences())
    }

    @Test func roundTrips() async throws {
        let suite = "io.pane.player.tests.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsPreferencesRepository(suiteName: suite)
        let preferences = PlaybackPreferences(
            defaultRate: 1.25,
            skipInterval: .seconds(30),
            resume: .ask,
            usesHardwareDecoding: false,
            allowsVolumeBoost: false,
            gestures: GesturePreferences(adjustsBrightnessAndVolume: false, doubleTapSeeks: true, longPressSpeedsUp: false)
        )
        try await repository.save(preferences)
        #expect(try await repository.playbackPreferences() == preferences)
    }

    @Test func missingFieldsFallBackToDefaults() async throws {
        let suite = "io.pane.player.tests.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        UserDefaults(suiteName: suite)?.set(Data(#"{"skipSeconds":15}"#.utf8), forKey: "playbackPreferences")
        let repository = UserDefaultsPreferencesRepository(suiteName: suite)
        #expect(try await repository.playbackPreferences() == PlaybackPreferences(skipInterval: .seconds(15)))
    }
}
