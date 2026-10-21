import SwiftUI

public enum NetworkFailure: Error, Hashable, Sendable {
    case saveFailed
    case removeFailed

    var title: LocalizedStringKey {
        switch self {
        case .saveFailed: "Couldn't Save the Server"
        case .removeFailed: "Couldn't Remove the Server"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .saveFailed: "The server or its password wasn't saved. Try again."
        case .removeFailed: "The server is still saved. Try again."
        }
    }
}
