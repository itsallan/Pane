import Foundation
import Photos
import PlayerFeature

/// Adds captured frames to the user's library with add-only access, the narrowest Photos permission there is.
struct SystemPhotoLibrary: PhotoLibrary {
    nonisolated func addImage(at url: URL) async throws(PhotoLibraryError) {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw .accessDenied }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: url, options: options)
            }
        } catch {
            throw .saveFailed
        }
    }
}
