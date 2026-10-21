import Domain
import NetworkFeature
import SwiftUI

/// The network column on iPad and Mac and the Network tab on iPhone: servers, their folders and Open URL.
struct NetworkStack: View {
    @Bindable var router: AppRouter
    let onOpen: (MediaItem) -> Void

    var body: some View {
        NavigationStack(path: $router.networkPath) {
            NetworkScreen(model: router.networkModel)
                .navigationDestination(for: NetworkRoute.self, destination: destination)
        }
        .onChange(of: router.networkPath) {
            router.networkPathDidChange()
        }
    }

    @ViewBuilder
    private func destination(_ route: NetworkRoute) -> some View {
        switch route {
        case .openURL:
            OpenURLScreen(model: router.openURLModel, onOpen: openStream)
        case .folder:
            if let model = router.browserModel(for: route) {
                ShareBrowserScreen(model: model, onOpen: openFile)
            }
        }
    }

    private func openStream(_ url: URL) {
        Task {
            guard let item = await router.itemForStream(url) else { return }
            onOpen(item)
        }
    }

    private func openFile(_ server: NetworkServer, _ entry: NetworkEntry) {
        Task {
            guard let item = await router.itemForNetworkFile(entry, on: server) else { return }
            onOpen(item)
        }
    }
}
