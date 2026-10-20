public protocol LibraryRepository: Sendable {
    func items() async throws -> [MediaItem]
    func item(withID id: MediaItem.ID) async throws -> MediaItem?
    func save(_ item: MediaItem) async throws
    func deleteItem(withID id: MediaItem.ID) async throws
}
