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
                .navigationDestination(for: NetworkRoute.self) { route in
                    NetworkDestination(route: route, router: router, onOpenStream: openStream, onOpenFile: openFile)
                }
        }
        .onChange(of: router.networkPath) {
            router.networkPathDidChange()
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
