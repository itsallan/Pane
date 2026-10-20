#if DEBUG
import Domain
import PlaybackTesting
import SwiftUI

private extension PlayerModel {
    static func preview(_ state: PlaybackState) -> PlayerModel {
        PlayerModel(
            engine: FakePlaybackEngine(stateOnLoad: state),
            source: .stream(URL(filePath: "/preview.mkv")),
            title: "Big Buck Bunny",
            thumbnails: FakeThumbnailProvider()
        )
    }
}

private extension PlaybackState {
    static func preview(_ status: Status) -> PlaybackState {
        PlaybackState(
            status: status,
            progress: PlaybackProgress(position: .seconds(212), duration: .seconds(596)),
            tracks: [
                MediaTrack(id: "audio/1", kind: .audio, language: "en", title: "English 5.1"),
                MediaTrack(id: "audio/2", kind: .audio, language: "fr"),
                MediaTrack(id: "spu/3", kind: .subtitle, language: "en"),
            ],
            selectedTrackIDs: ["audio/1"],
            chapters: [
                Chapter(id: 0, title: "Opening", start: .zero),
                Chapter(id: 1, title: "The Meadow", start: .seconds(120)),
                Chapter(id: 2, title: "Ambush", start: .seconds(330)),
                Chapter(id: 3, title: "Revenge", start: .seconds(470)),
            ],
            isSeekable: true
        )
    }
}

private struct PreviewFrame: View {
    var body: some View {
        LinearGradient(colors: [.indigo, .teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Playing") {
    PlayerScreen(model: .preview(.preview(.playing)), onDismiss: {}) { PreviewFrame() }
}

#Preview("Playing, dark") {
    PlayerScreen(model: .preview(.preview(.playing)), onDismiss: {}) { PreviewFrame() }
        .preferredColorScheme(.dark)
}

#Preview("Buffering") {
    PlayerScreen(model: .preview(.preview(.buffering(0.4))), onDismiss: {}) { PreviewFrame() }
}

#Preview("Buffering, dark") {
    PlayerScreen(model: .preview(.preview(.buffering(0.4))), onDismiss: {}) { PreviewFrame() }
        .preferredColorScheme(.dark)
}

#Preview("Error") {
    PlayerScreen(model: .preview(.preview(.failed(.networkFailed))), onDismiss: {}) { PreviewFrame() }
}

#Preview("Error, dark") {
    PlayerScreen(model: .preview(.preview(.failed(.networkFailed))), onDismiss: {}) { PreviewFrame() }
        .preferredColorScheme(.dark)
}
#endif
