public struct SubtitleStyle: Sendable, Hashable, Codable {
    public enum Size: String, Sendable, Hashable, Codable, CaseIterable {
        case small
        case medium
        case large
        case extraLarge
    }

    public enum Background: String, Sendable, Hashable, Codable, CaseIterable {
        /// Outlined text with no box behind it.
        case none
        case translucent
        case solid
    }

    public enum Position: String, Sendable, Hashable, Codable, CaseIterable {
        case bottom
        case raised
        case high
    }

    public var size: Size
    public var background: Background
    public var position: Position

    public init(size: Size = .medium, background: Background = .none, position: Position = .bottom) {
        self.size = size
        self.background = background
        self.position = position
    }
}
