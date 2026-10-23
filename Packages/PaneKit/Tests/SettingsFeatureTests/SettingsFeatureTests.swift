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
