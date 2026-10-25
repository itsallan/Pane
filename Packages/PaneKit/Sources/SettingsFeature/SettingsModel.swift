import Domain
import Foundation
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

    public static let defaultRates = [0.5, 0.75, 1, 1.25, 1.5, 2]

    public private(set) var isSyncEnabled: Bool
    public var playback = PlaybackPreferences() {
        didSet { save(playback, changed: playback != oldValue) }
    }
    public var tracks = TrackPreferences() {
        didSet { save(tracks, changed: tracks != oldValue) }
    }
    public var subtitleStyle = SubtitleStyle() {
        didSet {
            guard subtitleStyle != oldValue, isLoaded else { return }
            onSubtitleStyleChange?(subtitleStyle)
            let style = subtitleStyle
            enqueue { try? await $0.save(style) }
        }
    }

    private let launchStatus: CloudSyncStatus
    private let preferences: any PreferencesRepository
    private let onSubtitleStyleChange: ((SubtitleStyle) -> Void)?
    // Loading assigns every preference; those assignments shouldn't write straight back.
    private var isLoaded = false

    /// `launchStatus` is how the store opened on this run, which is what's actually happening until the next launch.
    /// `onSubtitleStyleChange` lets the app hand the new style to the next player, since libvlc only reads it at creation.
    public init(
        preferences: any PreferencesRepository,
        launchStatus: CloudSyncStatus,
        onSubtitleStyleChange: ((SubtitleStyle) -> Void)? = nil
    ) {
        self.preferences = preferences
        self.launchStatus = launchStatus
        self.onSubtitleStyleChange = onSubtitleStyleChange
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
        isLoaded = false
        isSyncEnabled = await preferences.syncsWithCloud()
        playback = (try? await preferences.playbackPreferences()) ?? PlaybackPreferences()
        tracks = (try? await preferences.trackPreferences()) ?? TrackPreferences()
        subtitleStyle = (try? await preferences.subtitleStyle()) ?? SubtitleStyle()
        isLoaded = true
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

    /// Writes finish in order because each one replaces the whole value, so a stale write can't land last.
    @ObservationIgnored private var pendingWrite: Task<Void, Never>?

    /// Waits for the writes started so far; for tests.
    func flush() async {
        await pendingWrite?.value
    }

    private func save(_ preferences: PlaybackPreferences, changed: Bool) {
        guard changed, isLoaded else { return }
        enqueue { try? await $0.save(preferences) }
    }

    private func save(_ preferences: TrackPreferences, changed: Bool) {
        guard changed, isLoaded else { return }
        enqueue { try? await $0.save(preferences) }
    }

    private func enqueue(_ write: @escaping @Sendable (any PreferencesRepository) async -> Void) {
        let previous = pendingWrite
        pendingWrite = Task { [preferences] in
            await previous?.value
            await write(preferences)
        }
    }
}
