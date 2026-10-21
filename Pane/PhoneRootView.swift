#if os(iOS)
import Domain
import LibraryFeature
import SwiftUI

struct PhoneRootView: View {
    @Bindable var router: AppRouter
    let onOpen: (MediaItem) -> Void

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Library", systemImage: "film.stack", value: .library) {
                NavigationStack(path: $router.libraryPath) {
                    LibraryScreen(model: router.model(for: .all), showsFolders: true, onOpen: onOpen)
                        #if DEBUG
                        .toolbar {
                            SampleStreamsButton(router: router)
                        }
                        #endif
                        .navigationDestination(for: LibraryScope.self) { scope in
                            LibraryScreen(model: router.model(for: scope), onOpen: onOpen)
                        }
                }
            }
            Tab("Recents", systemImage: "clock", value: .recents) {
                NavigationStack {
                    LibraryScreen(model: router.model(for: .recents), onOpen: onOpen)
                }
            }
            Tab("Network", systemImage: "network", value: .network) {
                NetworkStack(router: router, onOpen: onOpen)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
#endif
