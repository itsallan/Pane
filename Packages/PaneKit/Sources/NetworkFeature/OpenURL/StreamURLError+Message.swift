import Domain
import SwiftUI

extension StreamURLError {
    var message: LocalizedStringKey {
        switch self {
        case .empty: "Enter a stream address."
        case .malformed: "That isn't a valid address."
        case .unsupportedScheme(let scheme): "Pane can't open \(scheme):// links here. For SMB or SFTP, add the server under Network."
        case .containsPassword: "Remove the user name and password from the link. Pane doesn't keep passwords in links."
        }
    }
}
