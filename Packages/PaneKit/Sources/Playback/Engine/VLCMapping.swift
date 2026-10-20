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
