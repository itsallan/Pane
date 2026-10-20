import Domain

public actor InMemoryLibraryRepository: LibraryRepository {
    private var storage: [MediaItem.ID: MediaItem]

    public init(items: [MediaItem] = []) {
        storage = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    }

    public func items() async throws -> [MediaItem] {
        Array(storage.values)
    }

    public func item(withID id: MediaItem.ID) async throws -> MediaItem? {
        storage[id]
    }

    public func save(_ item: MediaItem) async throws {
        storage[item.id] = item
    }

    public func deleteItem(withID id: MediaItem.ID) async throws {
        storage[id] = nil
    }
}
