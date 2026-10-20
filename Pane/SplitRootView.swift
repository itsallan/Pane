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
            let scope = router.sidebarSelection ?? .all
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
        }
    }
}
