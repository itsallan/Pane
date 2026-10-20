import Domain
import Foundation

/// Until Settings exists, nothing saves preferences, so the system's preferred languages decide.
public struct UserDefaultsPreferencesRepository: PreferencesRepository {
    private static let key = "trackPreferences"

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
