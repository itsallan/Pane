import Foundation

public protocol StreamHistoryRepository: Sendable {
    /// Most recent first.
    func recentStreams() async throws -> [RecentStream]
    func record(_ url: URL, at date: Date) async throws
    func deleteStream(_ url: URL) async throws
    func deleteAllStreams() async throws
}
