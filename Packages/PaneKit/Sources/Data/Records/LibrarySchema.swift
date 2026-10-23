import Foundation
import SwiftData

extension ModelContainer {
    /// Has to match the container in the app's entitlements and the one created in the developer portal.
    public static let cloudContainerIdentifier = "iCloud.io.pane.player"

    private static let schema = Schema([
        MediaItemRecord.self, FolderRecord.self, ProgressRecord.self, NetworkServerRecord.self, RecentStreamRecord.self,
    ])

    /// The library store. Tests pass `inMemory: true` so each one starts empty.
    public static func library(inMemory: Bool = false, syncsWithCloud: Bool = false) throws -> ModelContainer {
        // `.none` rather than the default `.automatic`, which would start syncing as soon as the app had an iCloud
        // entitlement, whatever the setting says.
        let configuration = ModelConfiguration(
            "Library",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: syncsWithCloud ? .private(cloudContainerIdentifier) : .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func library(at url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration("Library", schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
