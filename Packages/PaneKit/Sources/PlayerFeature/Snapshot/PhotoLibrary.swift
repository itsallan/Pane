import Foundation

/// Where captured frames go, injected by the app target so the feature never imports Photos.
public protocol PhotoLibrary: Sendable {
    /// Takes ownership of the file at `url`.
    func addImage(at url: URL) async throws(PhotoLibraryError)
}

public enum PhotoLibraryError: Error, Sendable {
    case accessDenied
    case saveFailed
}
