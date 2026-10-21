import Domain
import SwiftUI

struct RecentStreamsSection: View {
    let model: OpenURLModel
    let onReopen: (RecentStream) -> Void

    @State private var isConfirmingClear = false

    var body: some View {
        Section {
            ForEach(model.recents) { stream in
                Button {
                    onReopen(stream)
                } label: {
                    RecentStreamRow(stream: stream)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Remove from History", systemImage: "trash", role: .destructive) {
                        remove(stream)
                    }
                }
            }
            .onDelete(perform: remove)
        } header: {
            HStack {
                Text("Recent")
                Spacer()
                Button("Clear", role: .destructive, action: confirmClear)
                    .textCase(nil)
                    .confirmationDialog("Clear stream history?", isPresented: $isConfirmingClear) {
                        Button("Clear History", role: .destructive, action: clearHistory)
                    } message: {
                        Text("Streams you've already played stay in your library.")
                    }
            }
        }
    }

    private func confirmClear() {
        isConfirmingClear = true
    }

    private func remove(_ stream: RecentStream) {
        Task { await model.remove(stream) }
    }

    private func remove(at offsets: IndexSet) {
        let streams = offsets.map { model.recents[$0] }
        Task {
            for stream in streams {
                await model.remove(stream)
            }
        }
    }

    private func clearHistory() {
        Task { await model.clearHistory() }
    }
}
