import Domain
import Foundation
import SwiftUI

extension Duration {
    var timecode: String {
        let pattern: Duration.TimeFormatStyle.Pattern = self >= .seconds(3600) ? .hourMinuteSecond : .minuteSecond
        return formatted(.time(pattern: pattern))
    }
}

extension MediaTrack {
    var displayName: String {
        if let title, !title.isEmpty { return title }
        if let language, let name = Locale.current.localizedString(forIdentifier: language) { return name }
        return language ?? id
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
        case .decodingFailed: "This video can't be decoded."
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
