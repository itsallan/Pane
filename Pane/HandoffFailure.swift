import Domain
import Foundation

/// Why something handed off from another device can't play here.
struct HandoffFailure: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(_ error: HandoffError) {
        switch error {
        case .fileUnavailable(let name):
            title = String(localized: "Can’t Continue “\(name)”")
            message = String(localized: "This video is a file on your other device. Add it to the library here to keep watching.")
        case .libraryUnavailable:
            title = String(localized: "Can’t Continue Watching")
            message = String(localized: "Pane couldn’t add this video to the library.")
        }
    }
}
