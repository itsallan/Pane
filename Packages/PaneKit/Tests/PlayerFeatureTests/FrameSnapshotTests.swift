import Domain
import Foundation
import PlaybackTesting
import Testing
@testable import PlayerFeature

@MainActor
struct FrameSnapshotTests {
    private let clock = ManualClock()
    private let frame = URL(filePath: "/tmp/frame.png")

    private func makeModel(engine: FakePlaybackEngine, library: (any PhotoLibrary)?) -> PlayerModel {
        PlayerModel(engine: engine, source: .stream(URL(filePath: "/movie.mkv")), photoLibrary: library, clock: clock)
    }

    @Test func savesTheCapturedFrameAndClearsTheMessage() async {
        let engine = FakePlaybackEngine(capturedFrameURL: frame)
        let library = RecordingPhotoLibrary()
        let model = makeModel(engine: engine, library: library)

        await model.snapshot.capture()

        #expect(engine.calls.contains(.captureFrame))
        #expect(await library.added == [frame])
        #expect(model.snapshot.outcome == .saved)
        await settle()
        clock.advance(by: FrameSnapshot.outcomeDuration)
        await eventually { model.snapshot.outcome == nil }
    }

    @Test func reportsDeniedAccess() async {
        let model = makeModel(engine: FakePlaybackEngine(), library: RecordingPhotoLibrary(failure: .accessDenied))

        await model.snapshot.capture()

        #expect(model.snapshot.outcome == .accessDenied)
    }

    @Test func aFailedCaptureNeverReachesPhotos() async {
        let engine = FakePlaybackEngine(failures: .init(captureFrame: .captureFailed))
        let library = RecordingPhotoLibrary()
        let model = makeModel(engine: engine, library: library)

        await model.snapshot.capture()

        #expect(model.snapshot.outcome == .failed)
        #expect(await library.added.isEmpty)
    }

    @Test func unavailableWithoutALibrary() {
        #expect(!makeModel(engine: FakePlaybackEngine(), library: nil).snapshot.isAvailable)
    }
}

private actor RecordingPhotoLibrary: PhotoLibrary {
    private(set) var added: [URL] = []
    private let failure: PhotoLibraryError?

    init(failure: PhotoLibraryError? = nil) {
        self.failure = failure
    }

    func addImage(at url: URL) async throws(PhotoLibraryError) {
        if let failure {
            throw failure
        }
        added.append(url)
    }
}
