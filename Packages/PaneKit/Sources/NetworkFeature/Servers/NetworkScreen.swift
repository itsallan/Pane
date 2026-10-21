import Domain
import SwiftUI

/// Saved and nearby servers, plus the way into Open URL. Folders and Open URL are pushed as `NetworkRoute`s,
/// which the app's navigation stack resolves.
public struct NetworkScreen: View {
    @Bindable private var model: NetworkModel
    @State private var isAddingServer = false

    public init(model: NetworkModel) {
        self.model = model
    }

    public var body: some View {
        List {
            Section {
                NavigationLink(value: NetworkRoute.openURL) {
                    Label("Open URL", systemImage: "link")
                }
            }
            if !model.savedServers.isEmpty {
                Section("Saved") {
                    ForEach(model.savedServers) { server in
                        NavigationLink(value: server.rootRoute) {
                            ServerRow(server: server)
                        }
                        .contextMenu {
                            Button("Remove Server", systemImage: "trash", role: .destructive) {
                                remove(server)
                            }
                        }
                        .swipeActions {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                remove(server)
                            }
                        }
                    }
                }
            }
            Section {
                ForEach(model.nearbyServers) { server in
                    NavigationLink(value: server.rootRoute) {
                        ServerRow(server: server)
                    }
                }
                if model.nearbyServers.isEmpty {
                    Label {
                        Text("Looking for servers…")
                            .foregroundStyle(.secondary)
                    } icon: {
                        ProgressView()
                    }
                }
            } header: {
                Text("Nearby")
            } footer: {
                Text("Pane finds SMB and UPnP servers on your network. Add SFTP servers, or SMB servers that don't show up, by hand.")
            }
        }
        .navigationTitle("Network")
        .toolbar {
            Button("Add Server", systemImage: "plus") {
                isAddingServer = true
            }
        }
        .sheet(isPresented: $isAddingServer) {
            AddServerSheet(onSave: add)
        }
        .alert(
            Text(model.failure?.title ?? ""),
            isPresented: $model.isShowingFailure,
            presenting: model.failure
        ) { _ in
        } message: { failure in
            Text(failure.message)
        }
        .task {
            await model.load()
        }
        .task {
            await model.discover()
        }
    }

    private func add(_ server: NetworkServer, credential: NetworkCredential?) {
        Task { await model.add(server, credential: credential) }
    }

    private func remove(_ server: NetworkServer) {
        Task { await model.remove(server) }
    }
}
