#if DEBUG
import Domain
import PlaybackTesting
import SwiftUI

private extension PlayerModel {
    static func preview(_ state: PlaybackState) -> PlayerModel {
        let engine = FakePlaybackEngine(stateOnLoad: state)
        engine.setAmbientPalette(.preview)
        return PlayerModel(
            engine: engine,
            source: .stream(URL(filePath: "/preview.mkv")),
            title: "Big Buck Bunny",
            thumbnails: FakeThumbnailProvider()
        )
    }
}

private extension AmbientPalette {
    // Matches PreviewFrame: indigo at the top leading corner through teal to orange at the bottom trailing one.
    static let preview = AmbientPalette(swatches: [
        Swatch(red: 0.35, green: 0.30, blue: 0.85), Swatch(red: 0.25, green: 0.45, blue: 0.80), Swatch(red: 0.20, green: 0.60, blue: 0.70),
        Swatch(red: 0.25, green: 0.50, blue: 0.75), Swatch(red: 0.20, green: 0.65, blue: 0.65), Swatch(red: 0.55, green: 0.60, blue: 0.40),
        Swatch(red: 0.20, green: 0.65, blue: 0.65), Swatch(red: 0.60, green: 0.55, blue: 0.35), Swatch(red: 0.95, green: 0.55, blue: 0.15),
    ])
}

private extension PlaybackState {
    static func preview(_ status: Status) -> PlaybackState {
        PlaybackState(
            status: status,
            progress: PlaybackProgress(position: .seconds(212), duration: .seconds(596)),
            tracks: [
                MediaTrack(id: "video/0", kind: .video),
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
            isSeekable: true,
            videoSize: VideoSize(width: 1920, height: 1080)
        )
    }
}

private struct PreviewFrame: View {
    var body: some View {
        LinearGradient(colors: [.indigo, .teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
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
