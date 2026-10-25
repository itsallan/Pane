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
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                OpenURLCard()
                    .padding(.horizontal, Metrics.edgeInset)
                SavedServersSection(model: model, onAdd: presentAddServer)
                NearbyServersSection(servers: model.nearbyServers)
            }
            .padding(.vertical, Metrics.controlSpacing)
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
}
