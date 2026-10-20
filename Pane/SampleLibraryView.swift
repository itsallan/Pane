#if DEBUG
import Domain
import Playback
import PlayerFeature
import SwiftUI

/// Stand-in for the library until LibraryFeature and the router exist.
struct SampleLibraryView: View {
    private struct Sample: Identifiable {
        let title: String
        let url: URL

        var id: URL { url }
    }

    private static let samples: [Sample] = [
        Sample(title: "Big Buck Bunny (HLS)", url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!),
        Sample(title: "Matroska subtitles", url: URL(string: "https://raw.githubusercontent.com/ietf-wg-cellar/matroska-test-files/master/test_files/test5.mkv")!),
    ]

    @State private var session: PlayerSession?
    private let thumbnails = VLCThumbnailProvider()

    var body: some View {
        NavigationStack {
            List(Self.samples) { sample in
                Button(sample.title) {
                    session = PlayerSession(source: .stream(sample.url), title: sample.title, thumbnails: thumbnails)
                }
            }
            .navigationTitle("Samples")
        }
        #if os(iOS)
        .fullScreenCover(item: $session) { player($0) }
        #else
        .sheet(item: $session) { player($0).frame(minWidth: 800, minHeight: 450) }
        #endif
    }

    private func player(_ session: PlayerSession) -> some View {
        PlayerScreen(model: session.model, onDismiss: { self.session = nil }) {
            VideoSurface(session.drawable)
        }
        // Covers every way the cover or sheet can go away, including Escape on macOS.
        .onDisappear {
            Task { await session.close() }
        }
    }
}
#endif
