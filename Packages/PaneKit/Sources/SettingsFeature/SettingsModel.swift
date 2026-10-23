import Domain
import Observation

@MainActor
@Observable
public final class SettingsModel {
    /// What to tell people under the sync switch.
    public enum SyncNote: Sendable, Hashable {
        case invitation
        case active
        case startsNextLaunch
        case stopsNextLaunch
        case noAccount
        case unavailable
    }

    public private(set) var isSyncEnabled: Bool
    private let launchStatus: CloudSyncStatus
    private let preferences: any PreferencesRepository

    /// `launchStatus` is how the store opened on this run, which is what's actually happening until the next launch.
    public init(preferences: any PreferencesRepository, launchStatus: CloudSyncStatus) {
        self.preferences = preferences
        self.launchStatus = launchStatus
        isSyncEnabled = launchStatus != .off
    }

    /// For the toggle.
    public var syncsWithCloud: Bool {
        get { isSyncEnabled }
        set {
            isSyncEnabled = newValue
            Task { await preferences.setSyncsWithCloud(newValue) }
        }
    }

    public func load() async {
        isSyncEnabled = await preferences.syncsWithCloud()
    }

    public func setSyncsWithCloud(_ isOn: Bool) async {
        isSyncEnabled = isOn
        await preferences.setSyncsWithCloud(isOn)
    }

    public var syncNote: SyncNote {
        switch (isSyncEnabled, launchStatus) {
        case (true, .on): .active
        case (true, .off): .startsNextLaunch
        case (true, .noAccount): .noAccount
        case (true, .unavailable): .unavailable
        case (false, .on): .stopsNextLaunch
        case (false, _): .invitation
        }
    }
}
