import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class OpenURLModel {
    public var text = "" {
        didSet { error = nil }
    }
    public private(set) var error: StreamURLError?
    public private(set) var recents: [RecentStream] = []

    private let history: any StreamHistoryRepository
    private let parse = ParseStreamURL()

    public init(history: any StreamHistoryRepository) {
        self.history = history
    }

    public var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func load() async {
        recents = (try? await history.recentStreams()) ?? []
    }

    /// The URL to play, or `nil` with `error` set when the text isn't something Pane can open.
    public func submit() async -> URL? {
        let url: URL
        do throws(StreamURLError) {
            url = try parse(text)
        } catch {
            self.error = error
            return nil
        }
        await reopen(url)
        text = ""
        return url
    }

    public func reopen(_ url: URL) async {
        // History is a convenience; failing to record it shouldn't stop the stream from playing.
        try? await history.record(url, at: .now)
        await load()
    }

    public func remove(_ stream: RecentStream) async {
        try? await history.deleteStream(stream.url)
        await load()
    }

    public func clearHistory() async {
        try? await history.deleteAllStreams()
        await load()
    }
}
