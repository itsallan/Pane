#if os(macOS)
import Domain
import NetworkFeature
import SwiftUI

/// Open URL from the File menu, which works even with no library window open.
struct OpenURLWindow: View {
    static let id = "open-url"

    let dependencies: AppDependencies

    @State private var model: OpenURLModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _model = State(initialValue: OpenURLModel(history: dependencies.streamHistory))
    }

    var body: some View {
        NavigationStack {
            OpenURLScreen(model: model, onOpen: open)
        }
        .frame(minWidth: 420, minHeight: 280)
    }

    private func open(_ url: URL) {
        Task {
            guard let item = await dependencies.itemForStream(url) else { return }
            dependencies.libraryDidChange()
            openWindow(id: PlayerWindow.id, value: item.id)
            dismissWindow(id: Self.id)
        }
    }
}
#endif
