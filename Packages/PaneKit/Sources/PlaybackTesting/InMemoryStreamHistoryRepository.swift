import Domain
import Foundation

public actor InMemoryStreamHistoryRepository: StreamHistoryRepository {
    private var streams: [RecentStream]

    public init(streams: [RecentStream] = []) {
        self.streams = streams
    }

    public func recentStreams() async throws -> [RecentStream] {
        streams.sorted { $0.lastOpened > $1.lastOpened }
    }

    public func record(_ url: URL, at date: Date) async throws {
        streams.removeAll { $0.url == url }
        streams.append(RecentStream(url: url, lastOpened: date))
    }

    public func deleteStream(_ url: URL) async throws {
        streams.removeAll { $0.url == url }
    }

    public func deleteAllStreams() async throws {
        streams.removeAll()
    }
}
