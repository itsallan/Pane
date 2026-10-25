import Domain
import PlaybackTesting
import Testing
@testable import SettingsFeature

@MainActor
struct SettingsModelTests {
    @Test func syncIsOffUntilTurnedOn() async {
        let preferences = InMemoryPreferencesRepository()
        let model = SettingsModel(preferences: preferences, launchStatus: .off)
        await model.load()

        #expect(!model.isSyncEnabled)
        #expect(model.syncNote == .invitation)

        await model.setSyncsWithCloud(true)
        #expect(await preferences.syncsWithCloud())
        #expect(model.syncNote == .startsNextLaunch)
    }

    @Test(arguments: [
        (CloudSyncStatus.on, SettingsModel.SyncNote.active),
        (.noAccount, .noAccount),
        (.unavailable, .unavailable),
    ])
    func explainsHowThisLaunchOpenedTheLibrary(status: CloudSyncStatus, note: SettingsModel.SyncNote) async {
        let model = SettingsModel(preferences: InMemoryPreferencesRepository(syncsWithCloud: true), launchStatus: status)
        await model.load()
        #expect(model.syncNote == note)
    }

    @Test func turningOffWhileSyncingTakesEffectNextLaunch() async {
        let preferences = InMemoryPreferencesRepository(syncsWithCloud: true)
        let model = SettingsModel(preferences: preferences, launchStatus: .on)

        await model.setSyncsWithCloud(false)

        #expect(await !preferences.syncsWithCloud())
        #expect(model.syncNote == .stopsNextLaunch)
    }
}

@MainActor
struct SettingsPreferencesTests {
    @Test func loadsWhatWasSaved() async {
        let playback = PlaybackPreferences(defaultRate: 1.25, skipInterval: .seconds(30), resume: .never)
        let model = SettingsModel(preferences: InMemoryPreferencesRepository(playback: playback), launchStatus: .off)
        await model.load()
        #expect(model.playback == playback)
    }

    @Test func savesChangesButNotTheLoad() async throws {
        let preferences = InMemoryPreferencesRepository()
        let model = SettingsModel(preferences: preferences, launchStatus: .off)
        await model.load()

        model.playback.skipInterval = .seconds(15)
        model.playback.gestures.doubleTapSeeks = false
        model.tracks.subtitleMode = .always
        await model.flush()

        let saved = try await preferences.playbackPreferences()
        #expect(saved.skipInterval == .seconds(15))
        #expect(!saved.gestures.doubleTapSeeks)
        #expect(try await preferences.trackPreferences().subtitleMode == .always)
    }

    @Test func handsANewSubtitleStyleToTheNextPlayer() async throws {
        let preferences = InMemoryPreferencesRepository()
        var handedOver: [SubtitleStyle] = []
        let model = SettingsModel(preferences: preferences, launchStatus: .off) { handedOver.append($0) }
        await model.load()
        #expect(handedOver.isEmpty)

        model.subtitleStyle.size = .extraLarge
        await model.flush()
        #expect(handedOver == [SubtitleStyle(size: .extraLarge)])
        #expect(try await preferences.subtitleStyle() == SubtitleStyle(size: .extraLarge))
    }
}
