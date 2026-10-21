public struct SubtitleCue: Sendable, Hashable, Identifiable {
    /// The cue's position in the file, in start order.
    public let id: Int
    public var start: Duration
    public var end: Duration
    public var text: String

    public init(id: Int, start: Duration, end: Duration, text: String) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }
}
