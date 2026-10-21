import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import NetworkFeature

@MainActor
struct OpenURLModelTests {
    @Test func submittingRecordsHistoryAndClearsTheField() async {
        let model = OpenURLModel(history: InMemoryStreamHistoryRepository())
        model.text = "https://example.com/live.m3u8"

        let url = await model.submit()

        #expect(url == URL(string: "https://example.com/live.m3u8"))
        #expect(model.text.isEmpty)
        #expect(model.recents.map(\.url) == [url])
    }

    @Test func badTextExplainsItselfAndRecordsNothing() async {
        let model = OpenURLModel(history: InMemoryStreamHistoryRepository())
        model.text = "smb://nas.local/Movies"

        #expect(await model.submit() == nil)
        #expect(model.error == .unsupportedScheme("smb"))
        #expect(model.recents.isEmpty)

        model.text = "https://example.com"
        #expect(model.error == nil)
    }

    @Test func removesAndClearsHistory() async {
        let first = RecentStream(url: URL(string: "https://example.com/a.m3u8")!, lastOpened: .now)
        let second = RecentStream(url: URL(string: "rtsp://camera.local/stream")!, lastOpened: .now.addingTimeInterval(-60))
        let model = OpenURLModel(history: InMemoryStreamHistoryRepository(streams: [first, second]))
        await model.load()

        await model.remove(first)
        #expect(model.recents == [second])

        await model.clearHistory()
        #expect(model.recents.isEmpty)
    }
}
