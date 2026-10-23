import Domain
import Foundation

/// Until Settings exists, nothing saves preferences, so the system's preferred languages decide.
public struct UserDefaultsPreferencesRepository: PreferencesRepository {
    private static let key = "trackPreferences"
    private static let styleKey = "subtitleStyle"
    private static let cloudSyncKey = "syncsWithCloud"

    // UserDefaults isn't Sendable, so keep the suite name and look the store up per call.
    private let suiteName: String?

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func trackPreferences() async throws -> TrackPreferences {
        guard let data = defaults.data(forKey: Self.key),
              let stored = try? JSONDecoder().decode(StoredPreferences.self, from: data)
        else {
            let languages = Locale.preferredLanguages.map(Locale.Language.init(identifier:))
            return TrackPreferences(audioLanguages: languages, subtitleLanguages: languages)
        }
        return stored.trackPreferences
    }

    public func save(_ preferences: TrackPreferences) async throws {
        defaults.set(try JSONEncoder().encode(StoredPreferences(preferences)), forKey: Self.key)
    }

    public func subtitleStyle() async throws -> SubtitleStyle {
        guard let data = defaults.data(forKey: Self.styleKey) else { return SubtitleStyle() }
        // A style saved by a newer version with a case this one doesn't know falls back to the default.
        return (try? JSONDecoder().decode(SubtitleStyle.self, from: data)) ?? SubtitleStyle()
    }

    public func save(_ style: SubtitleStyle) async throws {
        defaults.set(try JSONEncoder().encode(style), forKey: Self.styleKey)
    }

    public func syncsWithCloud() async -> Bool {
        syncsWithCloudAtLaunch
    }

    public func setSyncsWithCloud(_ isOn: Bool) async {
        defaults.set(isOn, forKey: Self.cloudSyncKey)
    }

    /// For the composition root, which has to decide before anything async can run.
    public var syncsWithCloudAtLaunch: Bool {
        defaults.bool(forKey: Self.cloudSyncKey)
    }
}

private struct StoredPreferences: Codable {
    var audioLanguages: [String]
    var subtitleLanguages: [String]
    var subtitleMode: String

    init(_ preferences: TrackPreferences) {
        audioLanguages = preferences.audioLanguages.map(\.minimalIdentifier)
        subtitleLanguages = preferences.subtitleLanguages.map(\.minimalIdentifier)
        subtitleMode = switch preferences.subtitleMode {
        case .off: "off"
        case .auto: "auto"
        case .always: "always"
        }
    }

    var trackPreferences: TrackPreferences {
        let mode: TrackPreferences.SubtitleMode = switch subtitleMode {
        case "off": .off
        case "always": .always
        default: .auto
        }
        return TrackPreferences(
            audioLanguages: audioLanguages.map(Locale.Language.init(identifier:)),
            subtitleLanguages: subtitleLanguages.map(Locale.Language.init(identifier:)),
            subtitleMode: mode
        )
    }
}
