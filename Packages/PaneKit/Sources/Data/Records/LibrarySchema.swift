import SwiftData

extension ModelContainer {
    /// The library store. Tests pass `inMemory: true` so each one starts empty.
    public static func library(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([MediaItemRecord.self, FolderRecord.self, ProgressRecord.self])
        let configuration = ModelConfiguration("Library", schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
