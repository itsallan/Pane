import SwiftUI

struct NoMatchesView: View {
    let model: LibraryModel

    var body: some View {
        if model.searchText.isEmpty {
            ContentUnavailableView {
                Label("No Matching Videos", systemImage: "line.3.horizontal.decrease")
            } description: {
                Text("Nothing here matches the current filter.")
            } actions: {
                Button("Show All Videos", action: showAll)
            }
        } else {
            ContentUnavailableView.search
        }
    }

    private func showAll() {
        model.filter = .all
    }
}
