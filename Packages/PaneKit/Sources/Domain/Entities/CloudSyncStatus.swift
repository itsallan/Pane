/// How this run of the app opened its library. The sync setting is read once, when the store opens.
public enum CloudSyncStatus: Sendable, Hashable {
    case off
    case on
    /// Sync is turned on, but no one is signed in to iCloud.
    case noAccount
    /// Sync is turned on, but this build can't reach its iCloud container, for instance without a signing team.
    case unavailable
}
