import Domain
import Foundation
@preconcurrency import VLCKit

extension MediaTrack.Kind {
    init?(_ type: VLCMedia.TrackType) {
        switch type {
        case .audio: self = .audio
        case .video: self = .video
        case .text: self = .subtitle
        default: return nil
        }
    }
}

extension MediaTrack {
    init?(_ track: VLCMediaPlayer.Track, isDefault: Bool) {
        guard let kind = Kind(track.type) else { return nil }
        let name = track.trackName.isEmpty ? nil : track.trackName
        // libvlc 4 drops Matroska's FlagForced, but its generated track name keeps the word.
        let isForced = [track.trackName, track.trackDescription ?? ""].contains { $0.localizedCaseInsensitiveContains("forced") }
        self.init(
            id: track.trackId,
            kind: kind,
            language: track.language,
            title: name,
            isDefault: isDefault,
            isForced: isForced
        )
    }
}

extension Chapter {
    init(_ description: VLCMediaPlayer.ChapterDescription) {
        self.init(
            id: Int(description.chapterIndex),
            title: description.name,
            start: .milliseconds(description.timeOffset.value?.int64Value ?? 0)
        )
    }
}

extension SubtitleStyle {
    /// libvlc's text scale, where 1 is its default size.
    var fontScale: Float {
        switch size {
        case .small: 0.75
        case .medium: 1
        case .large: 1.3
        case .extraLarge: 1.6
        }
    }

    // freetype and the subpicture unit read these when a video output starts and never again,
    // so they can only be set on the libvlc instance a player is created with.
    var libraryOptions: [String] {
        var options: [String] = []
        switch background {
        case .none: break
        case .translucent: options += ["--freetype-background-opacity=128", "--freetype-background-color=0"]
        case .solid: options += ["--freetype-background-opacity=255", "--freetype-background-color=0"]
        }
        switch position {
        case .bottom: break
        case .raised: options.append("--sub-margin=80")
        case .high: options.append("--sub-margin=200")
        }
        return options
    }
}

extension VLCTime {
    var duration: Duration? {
        guard let value else { return nil }
        return .milliseconds(value.int64Value)
    }

    convenience init(_ duration: Duration) {
        self.init(number: NSNumber(value: duration.milliseconds))
    }
}

extension Duration {
    var milliseconds: Int64 {
        components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000
    }

    var microseconds: Int64 {
        components.seconds * 1_000_000 + components.attoseconds / 1_000_000_000_000
    }
}

extension PlaybackError {
    static func playbackFailure(isRemote: Bool) -> PlaybackError {
        isRemote ? .networkFailed : .decodingFailed
    }
}
