public struct MediaTrack: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable, CaseIterable {
        case audio
        case subtitle
        case video
    }

    public let id: String
    public var kind: Kind
    /// The tag as the container reports it: `en`, `eng`, `English` or anything else.
    public var language: String?
    public var title: String?
    public var isDefault: Bool
    public var isForced: Bool

    public init(id: String, kind: Kind, language: String? = nil, title: String? = nil, isDefault: Bool = false, isForced: Bool = false) {
        self.id = id
        self.kind = kind
        self.language = language
        self.title = title
        self.isDefault = isDefault
        self.isForced = isForced
    }
}
