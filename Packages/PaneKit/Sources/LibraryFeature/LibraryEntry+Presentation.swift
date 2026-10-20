import Domain
import Foundation

extension LibraryEntry {
    var watchedFraction: Double? {
        guard let resumePosition else { return nil }
        return PlaybackProgress(position: resumePosition, duration: item.duration).fractionWatched
    }

    var remaining: Duration? {
        guard let resumePosition, let duration = item.duration, duration > resumePosition else { return nil }
        return duration - resumePosition
    }

    var accessibilityLabel: String {
        if let remaining {
            let time = remaining.formatted(.units(allowed: [.hours, .minutes], width: .wide))
            return String(localized: "\(item.title), \(time) left")
        }
        if isWatched {
            return String(localized: "\(item.title), watched")
        }
        return item.title
    }
}
