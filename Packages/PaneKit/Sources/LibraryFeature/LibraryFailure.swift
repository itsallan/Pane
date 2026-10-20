import Foundation

public enum LibraryFailure: Hashable, Sendable {
    case loadFailed
    case importFailed
    case updateFailed

    var title: LocalizedStringResource {
        switch self {
        case .loadFailed: "Couldn't Load the Library"
        case .importFailed: "Couldn't Import"
        case .updateFailed: "Couldn't Update the Library"
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .loadFailed: "Your videos are still there. Try again in a moment."
        case .importFailed: "Pane couldn't read those files. Check that they're still available and try again."
        case .updateFailed: "The change wasn't saved. Try again."
        }
    }
}
