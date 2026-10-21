import Domain
import SwiftUI

/// One folder on a server. Subfolders push another `NetworkRoute`; files go out through `onOpen`.
public struct ShareBrowserScreen: View {
    @Bindable private var model: ShareBrowserModel
    private let onOpen: (NetworkServer, NetworkEntry) -> Void

    public init(model: ShareBrowserModel, onOpen: @escaping (NetworkServer, NetworkEntry) -> Void) {
        self.model = model
        self.onOpen = onOpen
    }

    public var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let failure):
                BrowseFailureView(failure: failure, serverName: model.server.displayName, onRetry: retry, onSignIn: requestSignIn)
            case .loaded where model.isEmpty:
                ContentUnavailableView("Empty Folder", systemImage: "folder", description: Text("There's nothing in this folder."))
            case .loaded:
                ShareListing(model: model, onOpen: onOpen)
            }
        }
        .navigationTitle(model.title)
        #if os(iOS)
        // Folder and server names run long; a large title would truncate most of them.
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $model.signInRequest) { request in
            SignInSheet(request: request, isSigningIn: model.isSigningIn, onSignIn: signIn)
        }
        .task {
            await model.loadIfNeeded()
        }
    }

    private func retry() {
        Task { await model.load() }
    }

    private func requestSignIn() {
        Task { await model.requestSignIn() }
    }

    private func signIn(_ credential: NetworkCredential) {
        Task { await model.signIn(credential) }
    }
}
