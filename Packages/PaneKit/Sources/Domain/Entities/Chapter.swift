public struct Chapter: Sendable, Hashable, Identifiable {
    public let id: Int
    public var title: String?
    public var start: Duration

    public init(id: Int, title: String? = nil, start: Duration) {
        self.id = id
        self.title = title
        self.start = start
    }
}
