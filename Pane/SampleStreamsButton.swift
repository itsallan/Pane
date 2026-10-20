#if DEBUG
import Domain
import Foundation
import SwiftUI

/// Public test streams, so a fresh simulator has something to play without importing files.
struct SampleStreamsButton: ToolbarContent {
    let router: AppRouter

    private static let samples: [(id: String, title: String, url: String)] = [
        ("8E7B2C1A-0000-4000-8000-000000000001", "Big Buck Bunny", "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"),
        ("8E7B2C1A-0000-4000-8000-000000000002", "Sintel", "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8"),
        ("8E7B2C1A-0000-4000-8000-000000000003", "Tears of Steel", "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8"),
        ("8E7B2C1A-0000-4000-8000-000000000004", "Matroska Subtitles", "https://raw.githubusercontent.com/ietf-wg-cellar/matroska-test-files/master/test_files/test5.mkv"),
    ]

    var body: some ToolbarContent {
        ToolbarItem(placement: .secondaryAction) {
            Button("Add Sample Streams", systemImage: "antenna.radiowaves.left.and.right", action: addSamples)
        }
    }

    private func addSamples() {
        Task { await router.addSamples(Self.samples.compactMap(Self.item)) }
    }

    private static func item(_ sample: (id: String, title: String, url: String)) -> MediaItem? {
        guard let id = UUID(uuidString: sample.id), let url = URL(string: sample.url) else { return nil }
        return MediaItem(id: id, title: sample.title, source: .stream(url))
    }
}

extension AppRouter {
    func addSamples(_ items: [MediaItem]) async {
        for item in items {
            try? await dependencies.library.save(item)
        }
        await reloadLibraries()
    }
}
#endif
