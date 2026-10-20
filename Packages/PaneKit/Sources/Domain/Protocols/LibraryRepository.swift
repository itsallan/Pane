public protocol LibraryRepository: Sendable {
    func items() async throws -> [MediaItem]
    func item(withID id: MediaItem.ID) async throws -> MediaItem?
    func save(_ item: MediaItem) async throws
    func deleteItem(withID id: MediaItem.ID) async throws

    func folders() async throws -> [LibraryFolder]
    func save(_ folder: LibraryFolder) async throws
    /// Deletes the folder together with its items.
    func deleteFolder(withID id: LibraryFolder.ID) async throws
}
