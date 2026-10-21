import Domain
import Foundation
import SwiftUI

extension Duration {
    /// "In sync", "0.35 s later" or "1.20 s earlier", for a subtitle delay.
    var delayDescription: String {
        guard self != .zero else { return String(localized: "In sync") }
        let seconds = abs(self / .seconds(1)).formatted(.number.precision(.fractionLength(2)))
        return self > .zero ? String(localized: "\(seconds) s later") : String(localized: "\(seconds) s earlier")
    }

    var timecode: String {
        let pattern: Duration.TimeFormatStyle.Pattern = self >= .seconds(3600) ? .hourMinuteSecond : .minuteSecond
        return formatted(.time(pattern: pattern))
    }
}

extension MediaTrack {
    var displayName: String {
        if let title, !title.isEmpty { return title }
        if let languageName { return languageName }
        return language ?? id
    }

    // Placeholder codes like "und" (undetermined) say nothing a person can use.
    private var languageName: String? {
        guard let language, !["und", "mul", "zxx", "mis"].contains(language) else { return nil }
        return Locale.current.localizedString(forIdentifier: language)
    }

    var detail: String? {
        var parts: [String] = []
        // VLC already writes the language into generated titles ("Track 1 - [English]").
        if let title, !title.isEmpty, let name = languageName, !title.localizedStandardContains(name) {
            parts.append(name)
        }
        if isForced {
            parts.append(String(localized: "Forced"))
        }
        if isDefault {
            parts.append(String(localized: "Default"))
        }
        return parts.isEmpty ? nil : parts.formatted()
    }
}

extension Chapter {
    var displayName: String {
        title ?? String(localized: "Chapter \(id + 1)")
    }
}

extension PlaybackError {
    var message: LocalizedStringKey {
        switch self {
        case .unresolvableBookmark: "The file has moved or is no longer accessible."
        case .unknownServer, .serverUnreachable: "The server can't be reached."
        case .authenticationRequired: "The server needs you to sign in."
        case .decodingFailed: "Pane can't play this video's format."
        case .networkFailed: "The connection was lost."
        case .unknownTrack, .unreadableSubtitle, .captureFailed, .thumbnailFailed: "Something went wrong."
        }
    }
}

extension Double {
    var rateLabel: String {
        formatted(.number.precision(.fractionLength(0...2))) + "×"
    }
}
