import DesignSystem
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
                    Label {
                        Text("Open URL")
                    } icon: {
                        IconTile(systemImage: "link", tint: .green)
                    }
                }
            }
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
                Button("Add Server…", systemImage: "plus", action: presentAddServer)
            }
            NearbyServersSection(servers: model.nearbyServers)
        }
        .navigationTitle("Network")
        .toolbar {
            Button("Add Server", systemImage: "plus", action: presentAddServer)
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

    private func presentAddServer() {
        isAddingServer = true
    }

    private func add(_ server: NetworkServer, credential: NetworkCredential?) {
        Task { await model.add(server, credential: credential) }
    }

    private func remove(_ server: NetworkServer) {
        Task { await model.remove(server) }
    }
}
