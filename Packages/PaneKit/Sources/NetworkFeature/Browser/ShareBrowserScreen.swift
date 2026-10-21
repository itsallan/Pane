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
        content
            .navigationTitle(model.title)
            .sheet(item: $model.signInRequest) { request in
                SignInSheet(request: request, onSignIn: signIn)
            }
            .task {
                await model.loadIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let failure):
            BrowseFailureView(failure: failure, serverName: model.server.displayName, onRetry: retry, onSignIn: requestSignIn)
        case .loaded where model.isEmpty:
            ContentUnavailableView("Empty Folder", systemImage: "folder", description: Text("There's nothing in this folder."))
                .refreshable { await model.load() }
        case .loaded:
            List {
                ForEach(model.folders, id: \.path) { folder in
                    NavigationLink(value: NetworkRoute.folder(model.server, path: folder.path, name: folder.name)) {
                        EntryRow(entry: folder)
                    }
                }
                ForEach(model.files, id: \.path) { file in
                    Button {
                        onOpen(model.server, file)
                    } label: {
                        EntryRow(entry: file)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(!file.isPlayable)
                }
            }
            .refreshable {
                await model.load()
            }
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
