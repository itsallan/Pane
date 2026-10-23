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
    @Environment(OpenedFiles.self) private var openedFiles
    #endif

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _router = State(initialValue: AppRouter(dependencies: dependencies))
    }

    var body: some View {
        root
            .onOpenURL(perform: openFile)
            .onContinueUserActivity(PlaybackActivity.type, perform: continueHandoff)
            .alert(
                router.handoffFailure?.title ?? "",
                isPresented: $router.isShowingHandoffFailure,
                presenting: router.handoffFailure
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { failure in
                Text(failure.message)
            }
            #if os(macOS)
            .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
            .onChange(of: openedFiles.pending, initial: true) {
                openFiles(openedFiles.take())
            }
            #endif
            .onChange(of: dependencies.libraryRevision) {
                Task { await router.reloadLibraries() }
            }
            .task {
                await dependencies.restoreFileAccess()
                await dependencies.loadSubtitleStyle()
            }
            #if os(iOS)
            .fullScreenCover(item: $router.presentedSession) { session in
                PlayerScreen(model: session.model, onDismiss: router.dismissPlayer) {
                    VideoSurface(session.drawable)
                }
                .userActivity(PlaybackActivity.type, isActive: session.model.failure == nil) { activity in
                    PlaybackActivity.update(activity, for: session)
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

    private func continueHandoff(_ activity: NSUserActivity) {
        guard let handoff = PlaybackActivity.handoff(from: activity) else { return }
        Task {
            do throws(HandoffError) {
                let item = try await dependencies.continueHandoff(handoff)
                #if os(macOS)
                openWindow(id: PlayerWindow.id, value: item.id)
                #else
                router.presentReplacing(item)
                #endif
            } catch {
                router.handoffFailure = HandoffFailure(error)
            }
        }
    }

    private func openFile(_ url: URL) {
        guard url.isFileURL else { return }
        openFiles([url])
    }

    private func openFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task {
            let items = await router.importForOpening(urls)
            items.forEach(open)
        }
    }
}
