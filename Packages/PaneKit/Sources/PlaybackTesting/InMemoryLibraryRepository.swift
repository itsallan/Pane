import Domain

public actor InMemoryLibraryRepository: LibraryRepository {
    private var storage: [MediaItem.ID: MediaItem]
    private var folderStorage: [LibraryFolder.ID: LibraryFolder]

    public init(items: [MediaItem] = [], folders: [LibraryFolder] = []) {
        storage = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        folderStorage = Dictionary(folders.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
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

    public func folders() async throws -> [LibraryFolder] {
        Array(folderStorage.values)
    }

    public func save(_ folder: LibraryFolder) async throws {
        folderStorage[folder.id] = folder
    }

    public func deleteFolder(withID id: LibraryFolder.ID) async throws {
        folderStorage[id] = nil
        storage = storage.filter { $0.value.folderID != id }
    }
}
