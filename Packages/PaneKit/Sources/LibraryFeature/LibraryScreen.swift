import Domain
import SwiftUI

/// The library for one scope. Opening an item goes out through `onOpen`; the app decides how the player appears.
public struct LibraryScreen: View {
    @Bindable private var model: LibraryModel
    private let showsFolders: Bool
    private let onOpen: (MediaItem) -> Void

    @State private var importKind = ImportKind.files
    @State private var isImporterPresented = false

    /// `showsFolders` lists imported folders inline, for layouts without a sidebar to hold them.
    public init(model: LibraryModel, showsFolders: Bool = false, onOpen: @escaping (MediaItem) -> Void) {
        self.model = model
        self.showsFolders = showsFolders
        self.onOpen = onOpen
    }

    public var body: some View {
        ZStack {
            if !model.hasLoaded {
                ProgressView()
            } else if model.isEmpty {
                LibraryEmptyView(scope: model.scope, onImport: presentImporter)
            } else {
                LibraryContent(model: model, showsFolders: showsFolders, onOpen: onOpen)
            }
        }
        .overlay {
            if model.hasLoaded, !model.isEmpty, model.entries.isEmpty {
                NoMatchesView(model: model)
            }
        }
        .navigationTitle(model.title)
        .toolbar {
            LibraryToolbar(model: model, onImport: presentImporter)
        }
        .searchable(text: $model.searchText, prompt: "Search Videos")
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: importKind.contentTypes,
            allowsMultipleSelection: importKind == .files,
            onCompletion: importFiles
        )
        .modifier(MediaDropTarget(isEnabled: model.canImport, onDrop: importDropped, onFailure: model.dropFailed))
        .alert(
            Text(model.failure?.title ?? ""),
            isPresented: $model.isShowingFailure,
            presenting: model.failure
        ) { _ in
        } message: { failure in
            Text(failure.message)
        }
        .task {
            await model.load()
        }
    }

    private func presentImporter(_ kind: ImportKind) {
        importKind = kind
        isImporterPresented = true
    }

    private func importFiles(_ result: Result<[URL], any Error>) {
        Task { await model.importResult(result) }
    }

    private func importDropped(_ urls: [URL]) {
        Task { await model.importMedia(at: urls) }
    }
}
