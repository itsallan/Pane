import Domain
import Foundation
@preconcurrency import VLCKit

struct MediaLocation: Sendable {
    let url: URL
    private let isSecurityScoped: Bool
    private var shareOptions: [String: String] = [:]

    /// A `.networkShare` needs its `share`, which the caller resolves from the server record and credential store.
    init(_ source: MediaSource, share: ShareAddress? = nil) throws(PlaybackError) {
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
            guard let share else { throw .unknownServer(server) }
            url = share.url
            shareOptions = share.options
            isSecurityScoped = false
        }
    }

    var isRemote: Bool { !url.isFileURL }

    func relinquish() {
        guard isSecurityScoped else { return }
        url.stopAccessingSecurityScopedResource()
    }

    func makeMedia(usesHardwareDecoding: Bool = true) -> VLCMedia? {
        guard let media = VLCMedia(url: url) else { return nil }
        media.addOptions(MediaOptions.options(isRemote: isRemote, usesHardwareDecoding: usesHardwareDecoding))
        media.addOptions(shareOptions)
        // scaletempo keeps the pitch at any rate. It's libvlc's default; the speed control depends on it, so say so.
        media.addOption(":audio-time-stretch")
        return media
    }
}

enum MediaOptions {
    static func options(isRemote: Bool, usesHardwareDecoding: Bool = true) -> [String: String] {
        var options: [String: String]
        if usesHardwareDecoding {
            // VideoToolbox first; avcodec catches what the hardware decoder refuses (old codecs, odd profiles).
            options = ["codec": "videotoolbox,avcodec,all"]
        } else {
            // avcodec would still hand video to VideoToolbox through its own hwaccel unless that's off too.
            options = ["codec": "avcodec,all", "avcodec-hw": "none"]
        }
        if isRemote {
            options["network-caching"] = "1500"
        }
        return options
    }
}
