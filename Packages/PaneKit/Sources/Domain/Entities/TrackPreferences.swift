import Foundation

public struct TrackPreferences: Sendable, Hashable {
    public enum SubtitleMode: Sendable, Hashable, CaseIterable {
        case off
        case auto
        case always
    }

    public var audioLanguages: [Locale.Language]
    public var subtitleLanguages: [Locale.Language]
    public var subtitleMode: SubtitleMode

    public init(audioLanguages: [Locale.Language] = [], subtitleLanguages: [Locale.Language] = [], subtitleMode: SubtitleMode = .auto) {
        self.audioLanguages = audioLanguages
        self.subtitleLanguages = subtitleLanguages
        self.subtitleMode = subtitleMode
    }
}
