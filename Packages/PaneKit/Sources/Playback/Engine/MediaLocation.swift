import Domain
import Foundation
@preconcurrency import VLCKit

struct MediaLocation: Sendable {
    let url: URL
    private let isSecurityScoped: Bool

    init(_ source: MediaSource) throws(PlaybackError) {
        switch source {
        case .stream(let url):
            self.url = url
            isSecurityScoped = false
        case .file(let bookmark):
            var isStale = false
            #if os(macOS)
            let options: URL.BookmarkResolutionOptions = .withSecurityScope
            #else
            let options: URL.BookmarkResolutionOptions = []
            #endif
            guard let url = try? URL(resolvingBookmarkData: bookmark, options: options, bookmarkDataIsStale: &isStale) else {
                throw .unresolvableBookmark
            }
            self.url = url
            isSecurityScoped = url.startAccessingSecurityScopedResource()
        case .networkShare(let server, _):
            // Shares need the server record and its credential, which arrive with the network browser.
            throw .unknownServer(server)
        }
    }

    var isRemote: Bool { !url.isFileURL }

    func relinquish() {
        guard isSecurityScoped else { return }
        url.stopAccessingSecurityScopedResource()
    }

    func makeMedia() -> VLCMedia? {
        guard let media = VLCMedia(url: url) else { return nil }
        media.addOptions(MediaOptions.options(isRemote: isRemote))
        return media
    }
}

enum MediaOptions {
    static func options(isRemote: Bool) -> [String: String] {
        var options = [
            // VideoToolbox first; avcodec catches what the hardware decoder refuses (old codecs, odd profiles).
            "codec": "videotoolbox,avcodec,all",
        ]
        if isRemote {
            options["network-caching"] = "1500"
        }
        return options
    }
}
