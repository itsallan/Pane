import Domain
import Foundation

/// Bookmarks for files and folders the user picked, so they stay reachable after relaunch.
/// Playback resolves them with the same options when it opens a file.
enum SecurityScopedBookmark {
    struct Resolution {
        var url: URL
        /// A fresh bookmark when the old one was stale and has to be replaced in the store.
        var refreshed: Data?
    }

    #if os(macOS)
    private static let creationOptions: URL.BookmarkCreationOptions = [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
    private static let resolutionOptions: URL.BookmarkResolutionOptions = .withSecurityScope
    #else
    // iOS bookmarks carry the sandbox extension implicitly; the security-scope options are macOS only.
    private static let creationOptions: URL.BookmarkCreationOptions = []
    private static let resolutionOptions: URL.BookmarkResolutionOptions = []
    #endif

    /// Call while the URL's security scope is active.
    static func make(for url: URL) throws -> Data {
        try url.bookmarkData(options: creationOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    static func resolve(_ bookmark: Data) throws(PlaybackError) -> Resolution {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: resolutionOptions, bookmarkDataIsStale: &isStale) else {
            throw .unresolvableBookmark
        }
        guard isStale else { return Resolution(url: url) }
        // A stale bookmark still resolved, but the file moved or was renamed; rebuilding it needs the scope open.
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return Resolution(url: url, refreshed: try? make(for: url))
    }
}
