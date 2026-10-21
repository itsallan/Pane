public enum BrowseFailure: Error, Hashable, Sendable {
    case unreachable
    case signInRequired
    case failed
}
