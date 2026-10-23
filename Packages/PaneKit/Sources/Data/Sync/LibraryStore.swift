import Domain
import Foundation
import os
import SwiftData

/// Opens the library store, syncing through iCloud when asked and when this device and build can.
/// Anything short of that opens the same store locally, so the app works the same without iCloud.
public enum LibraryStore {
    private static let logger = Logger(subsystem: "io.pane.player", category: "library-store")

    public static func open(syncsWithCloud: Bool) throws -> (container: ModelContainer, sync: CloudSyncStatus) {
        guard syncsWithCloud else {
            return (try .library(), .off)
        }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            return (try .library(), .noAccount)
        }
        do {
            return (try .library(syncsWithCloud: true), .on)
        } catch {
            // Without the iCloud entitlement, or with a container the signing team doesn't own, CloudKit refuses the store.
            logger.error("Opening the library with CloudKit failed: \(error)")
            return (try .library(), .unavailable)
        }
    }
}
