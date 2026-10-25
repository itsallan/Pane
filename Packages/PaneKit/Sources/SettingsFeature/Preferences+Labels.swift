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
