import Foundation

public enum HandoffError: Error, Sendable, Hashable {
    /// The file lives on the other device, or this one has it somewhere the library doesn't know.
    case fileUnavailable(title: String)
    case libraryUnavailable
}

/// Finds or adds the handed-off media in this device's library and saves the other device's position as its
/// resume point, so opening the item resumes there through the usual `ResumePlayback` rules.
public struct ContinueHandoff: Sendable {
    private let library: any LibraryRepository
    private let servers: any NetworkServerRepository
    private let progress: any ProgressRepository
    private let importer: any MediaImporter

    public init(
        library: any LibraryRepository,
        servers: any NetworkServerRepository,
        progress: any ProgressRepository,
        importer: any MediaImporter
    ) {
        self.library = library
        self.servers = servers
        self.progress = progress
        self.importer = importer
    }

    public func callAsFunction(_ handoff: PlaybackHandoff) async throws(HandoffError) -> MediaItem {
        let item: MediaItem
        do {
            item = try await self.item(for: handoff)
            try await progress.save(handoff.progress, for: item.id)
        } catch let error as HandoffError {
            throw error
        } catch {
            throw .libraryUnavailable
        }
        return item
    }

    private func item(for handoff: PlaybackHandoff) async throws -> MediaItem {
        switch handoff.source {
        case .stream(let url):
            return try await AddToLibrary(library: library)(.stream(url), title: handoff.title)
        case .share(let server, let path):
            let serverID = try await localServer(matching: server)
            return try await AddToLibrary(library: library)(.networkShare(server: serverID, path: path), title: handoff.title)
        case .file(let itemID):
            guard let item = try await openableFile(id: itemID, title: handoff.title) else {
                throw HandoffError.fileUnavailable(title: handoff.title)
            }
            return item
        }
    }

    // A server added by hand has a random ID on each device, so the same host is the same server.
    private func localServer(matching server: PlaybackHandoff.Server) async throws -> NetworkServer.ID {
        let saved = try await servers.servers()
        if let match = saved.first(where: { $0.kind == server.kind && $0.host == server.host && $0.port == server.port }) {
            return match.id
        }
        try await servers.save(server.networkServer)
        return server.id
    }

    private func openableFile(id: MediaItem.ID, title: String) async throws -> MediaItem? {
        if let item = try await library.item(withID: id), await canOpen(item) {
            return item
        }
        for item in try await library.items() where item.title == title {
            if await canOpen(item) {
                return item
            }
        }
        return nil
    }

    private func canOpen(_ item: MediaItem) async -> Bool {
        guard case .file(let bookmark) = item.source else { return false }
        return await importer.canOpen(bookmark)
    }
}
