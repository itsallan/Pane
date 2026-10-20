import Domain
import LibraryFeature
import PlayerFeature
import Playback
import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies

    @State private var router: AppRouter
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _router = State(initialValue: AppRouter(dependencies: dependencies))
    }

    var body: some View {
        root
            .onOpenURL(perform: openFile)
            .onChange(of: dependencies.libraryRevision) {
                Task { await router.reloadLibraries() }
            }
            .task {
                await dependencies.restoreFileAccess()
            }
            #if os(iOS)
            .fullScreenCover(item: $router.presentedSession) { session in
                PlayerScreen(model: session.model, onDismiss: router.dismissPlayer) {
                    VideoSurface(session.drawable)
                }
                // Covers every way the cover can go away, not just the close button.
                .onDisappear {
                    Task { await router.playerDidClose(session) }
                }
            }
            #endif
    }

    // Chosen by idiom at launch, not size class: a large iPhone in landscape is regular width,
    // and swapping roots on rotation would throw away the navigation path.
    @ViewBuilder
    private var root: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            PhoneRootView(router: router, onOpen: open)
        } else {
            SplitRootView(router: router, onOpen: open)
        }
        #else
        SplitRootView(router: router, onOpen: open)
        #endif
    }

    private func open(_ item: MediaItem) {
        #if os(macOS)
        openWindow(id: PlayerWindow.id, value: item.id)
        #else
        router.present(item)
        #endif
    }

    private func openFile(_ url: URL) {
        guard url.isFileURL else { return }
        Task {
            guard let item = await router.importForOpening([url]) else { return }
            open(item)
        }
    }
}
