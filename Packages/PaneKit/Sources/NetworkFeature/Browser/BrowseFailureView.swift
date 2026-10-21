import SwiftUI

struct BrowseFailureView: View {
    let failure: BrowseFailure
    let serverName: String
    let onRetry: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        switch failure {
        case .unreachable:
            ContentUnavailableView {
                Label("Can't Reach \(serverName)", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check that the server is on and connected to the same network, then try again.")
            } actions: {
                Button("Try Again", systemImage: "arrow.clockwise", action: onRetry)
                    .buttonStyle(.glassProminent)
            }
        case .signInRequired:
            ContentUnavailableView {
                Label("Sign In to \(serverName)", systemImage: "lock")
            } description: {
                Text("This server needs a user name and password.")
            } actions: {
                Button("Sign In", systemImage: "person.badge.key", action: onSignIn)
                    .buttonStyle(.glassProminent)
            }
        case .failed:
            ContentUnavailableView {
                Label("Couldn't Open This Folder", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Something went wrong while listing it. Try again in a moment.")
            } actions: {
                Button("Try Again", systemImage: "arrow.clockwise", action: onRetry)
                    .buttonStyle(.glassProminent)
            }
        }
    }
}
