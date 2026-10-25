import Domain
import Foundation

extension ResumeBehavior {
    var label: LocalizedStringResource {
        switch self {
        case .always: "Always"
        case .ask: "Ask"
        case .never: "Never"
        }
    }
}

extension TrackPreferences.SubtitleMode {
    var label: LocalizedStringResource {
        switch self {
        case .off: "Off"
        case .auto: "When Audio Is Foreign"
        case .always: "Always"
        }
    }
}

extension Locale.Language {
    var displayName: String {
        Locale.current.localizedString(forIdentifier: minimalIdentifier) ?? minimalIdentifier
    }
}

extension [Locale.Language] {
    /// "English", "English +2" or "None", for a settings row.
    var summary: String {
        guard let first else { return String(localized: "None") }
        guard count > 1 else { return first.displayName }
        return String(localized: "\(first.displayName) +\(count - 1)")
    }
}
