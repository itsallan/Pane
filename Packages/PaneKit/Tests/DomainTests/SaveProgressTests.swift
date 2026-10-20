import Domain
import Foundation
import PlaybackTesting
import Testing

struct SaveProgressTests {
    private let item = UUID()
    private let clock = ManualClock()
    private let repository = InMemoryProgressRepository()

    private func makeSaver() -> SaveProgress<ManualClock> {
        SaveProgress(item: item, repository: repository, clock: clock)
    }

    private func at(_ seconds: Int) -> PlaybackProgress {
        PlaybackProgress(position: .seconds(seconds), duration: .seconds(1000))
    }

    @Test func ticksWriteAtMostEveryTenSeconds() async throws {
        let save = makeSaver()
        for second in 0...25 {
            try await save(at(100 + second))
            clock.advance(by: .seconds(1))
        }
        #expect(await repository.writes == [.save(at(110), item), .save(at(120), item)])
    }

    @Test func firstTickDoesNotWriteBeforeTheWindowPasses() async throws {
        let save = makeSaver()
        try await save(at(0))
        clock.advance(by: .seconds(9))
        try await save(at(0))
        #expect(await repository.writes.isEmpty)
    }

    @Test(arguments: [SaveProgress<ManualClock>.Trigger.pause, .seekEnded, .close, .background])
    func immediateTriggersBypassTheThrottle(trigger: SaveProgress<ManualClock>.Trigger) async throws {
        let save = makeSaver()
        clock.advance(by: .seconds(1))
        try await save(at(42), trigger: trigger)
        #expect(await repository.writes == [.save(at(42), item)])
    }

    @Test func immediateWriteRestartsTheWindow() async throws {
        let save = makeSaver()
        clock.advance(by: .seconds(8))
        try await save(at(8), trigger: .pause)
        clock.advance(by: .seconds(5))
        try await save(at(13))
        clock.advance(by: .seconds(5))
        try await save(at(18))
        #expect(await repository.writes == [.save(at(8), item), .save(at(18), item)])
    }

    @Test func passingNinetyFivePercentMarksWatchedOnce() async throws {
        let save = makeSaver()
        clock.advance(by: .seconds(10))
        try await save(at(950))
        clock.advance(by: .seconds(10))
        try await save(at(960))
        try await save(at(1000), trigger: .close)
        #expect(await repository.writes == [.markWatched(item)])
        #expect(try await repository.progress(for: item) == nil)
        #expect(try await repository.watchedItems() == [item])
    }

    @Test func justUnderNinetyFivePercentStillSaves() async throws {
        let save = makeSaver()
        try await save(at(949), trigger: .pause)
        #expect(await repository.writes == [.save(at(949), item)])
    }

    @Test func liveStreamsAreNeverMarkedWatched() async throws {
        let save = makeSaver()
        let live = PlaybackProgress(position: .seconds(5000), duration: nil)
        try await save(live, trigger: .close)
        #expect(await repository.writes == [.save(live, item)])
    }
}
