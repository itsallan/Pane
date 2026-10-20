import Domain
import Foundation
import PlaybackTesting
import Testing

struct ResumePlaybackTests {
    private let item = MediaItem(title: "Clip", source: .stream(URL(filePath: "/clip.mkv")), duration: .seconds(600))

    private func resume(from saved: PlaybackProgress?, item: MediaItem? = nil) async throws -> (Duration?, FakePlaybackEngine) {
        let item = item ?? self.item
        let engine = FakePlaybackEngine()
        let progress = InMemoryProgressRepository(progress: saved.map { [item.id: $0] } ?? [:])
        let position = try await ResumePlayback(engine: engine, progress: progress)(item)
        return (position, engine)
    }

    @Test(arguments: [
        (Duration.seconds(29), nil),
        (.seconds(30), .seconds(30)),
        (.seconds(569), .seconds(569)),
        (.seconds(570), nil),
        (.seconds(600), nil),
    ] as [(Duration, Duration?)])
    func thresholds(saved: Duration, expected: Duration?) async throws {
        let (position, engine) = try await resume(from: PlaybackProgress(position: saved, duration: .seconds(600)))
        #expect(position == expected)
        let seeks = engine.calls.filter { if case .seek = $0 { true } else { false } }
        #expect(seeks == expected.map { [.seek(to: $0, precision: .exact)] } ?? [])
    }

    @Test(arguments: [
        (Duration.seconds(29), nil),
        (.seconds(30), .seconds(30)),
        (.seconds(7200), .seconds(7200)),
    ] as [(Duration, Duration?)])
    func unknownDurationResumesFromThirtySeconds(saved: Duration, expected: Duration?) async throws {
        let live = MediaItem(title: "Live", source: .stream(URL(string: "https://example.com/live.m3u8")!))
        let (position, _) = try await resume(from: PlaybackProgress(position: saved, duration: nil), item: live)
        #expect(position == expected)
    }

    @Test func fallsBackToItemDurationWhenSavedOneIsUnknown() async throws {
        let (position, _) = try await resume(from: PlaybackProgress(position: .seconds(590), duration: nil))
        #expect(position == nil)
    }

    @Test func loadsBeforeSeeking() async throws {
        let (_, engine) = try await resume(from: PlaybackProgress(position: .seconds(120), duration: .seconds(600)))
        #expect(engine.calls == [.load(item.source), .seek(to: .seconds(120), precision: .exact)])
    }

    @Test func startsFromBeginningWithoutSavedProgress() async throws {
        let (position, engine) = try await resume(from: nil)
        #expect(position == nil)
        #expect(engine.calls == [.load(item.source)])
    }

    @Test func unreadableProgressStillPlays() async throws {
        let engine = FakePlaybackEngine()
        let progress = InMemoryProgressRepository(failsReads: true)
        let position = try await ResumePlayback(engine: engine, progress: progress)(item)
        #expect(position == nil)
        #expect(engine.calls == [.load(item.source)])
    }

    @Test func loadFailureThrowsWithoutSeeking() async {
        let engine = FakePlaybackEngine(failures: .init(load: .unresolvableBookmark))
        let progress = InMemoryProgressRepository(progress: [item.id: PlaybackProgress(position: .seconds(120), duration: .seconds(600))])
        await #expect(throws: PlaybackError.unresolvableBookmark) {
            try await ResumePlayback(engine: engine, progress: progress)(item)
        }
        #expect(engine.calls == [.load(item.source)])
    }
}
