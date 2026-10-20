#if os(macOS)
import DesignSystem
import Domain
import Playback
import PlayerFeature
import SwiftUI

struct PlayerWindow: View {
    static let id = "player"

    let itemID: MediaItem.ID?
    let dependencies: AppDependencies

    @State private var session: PlayerSession?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.mediaBackground
            if let session {
                PlayerScreen(model: session.model, onDismiss: close) {
                    VideoSurface(session.drawable)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 270)
        .navigationTitle(session?.model.title ?? "")
        .task {
            await openSession()
        }
        // Closing the window any way at all (the close button, Command-W) ends playback and saves progress.
        .onDisappear(perform: closeSession)
    }

    private func openSession() async {
        guard session == nil, let itemID, let item = try? await dependencies.library.item(withID: itemID) else { return }
        session = PlayerSession(item: item, dependencies: dependencies)
    }

    private func close() {
        dismiss()
    }

    private func closeSession() {
        guard let session else { return }
        self.session = nil
        Task {
            await session.close()
            dependencies.libraryDidChange()
        }
    }
}
#endif
