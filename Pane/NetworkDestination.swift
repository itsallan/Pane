import Domain
import NetworkFeature
import SwiftUI

struct NetworkDestination: View {
    let route: NetworkRoute
    let router: AppRouter
    let onOpenStream: (URL) -> Void
    let onOpenFile: (NetworkServer, NetworkEntry) -> Void

    var body: some View {
        switch route {
        case .openURL:
            OpenURLScreen(model: router.openURLModel, onOpen: onOpenStream)
        case .folder:
            if let model = router.browserModel(for: route) {
                ShareBrowserScreen(model: model, onOpen: onOpenFile)
            }
        }
    }
}
