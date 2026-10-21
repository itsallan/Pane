import Domain
import LibraryFeature
import SwiftUI

struct SplitRootView: View {
    @Bindable var router: AppRouter
    let onOpen: (MediaItem) -> Void

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(router: router)
        } detail: {
            switch router.sidebarSelection ?? .library(.all) {
            case .library(let scope):
                NavigationStack {
                    LibraryScreen(model: router.model(for: scope), onOpen: onOpen)
                        #if DEBUG
                        .toolbar {
                            SampleStreamsButton(router: router)
                        }
                        #endif
                }
                // Each scope gets its own stack, so search and scroll position don't leak between them.
                .id(scope)
            case .network:
                NetworkStack(router: router, onOpen: onOpen)
            }
        }
    }
}
