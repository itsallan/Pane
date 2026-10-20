import DesignSystem
import Domain
import SwiftUI

struct ContinueWatchingCard: View {
    let entry: LibraryEntry
    let model: LibraryModel
    let onOpen: (MediaItem) -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 6) {
                PosterImage(item: entry.item, model: model)
                    .overlay(alignment: .bottom) {
                        EntryProgressBar(fraction: entry.watchedFraction ?? 0)
                            .padding(8)
                    }
                Text(entry.item.title)
                    .font(.subheadline)
                    .lineLimit(1)
                EntryStatusText(entry: entry)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(width: Metrics.continueWatchingWidth)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu {
            EntryActions(entry: entry, model: model, onOpen: onOpen)
        }
        .accessibilityLabel(entry.accessibilityLabel)
        .accessibilityHint("Resumes the video")
    }

    private func open() {
        onOpen(entry.item)
    }
}
