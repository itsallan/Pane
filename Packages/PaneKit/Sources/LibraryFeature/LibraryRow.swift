import DesignSystem
import Domain
import SwiftUI

struct LibraryRow: View {
    let entry: LibraryEntry
    let model: LibraryModel
    let onOpen: (MediaItem) -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                PosterImage(item: entry.item, model: model)
                    .frame(width: Metrics.rowPosterWidth)
                    .overlay(alignment: .bottom) {
                        EntryProgressBar(fraction: entry.watchedFraction ?? 0)
                            .padding(6)
                            .opacity(entry.watchedFraction == nil ? 0 : 1)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.item.title)
                        .font(.body)
                        .lineLimit(2)
                    EntryStatusText(entry: entry)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu {
            EntryActions(entry: entry, model: model, onOpen: onOpen)
        }
        .swipeActions(edge: .leading) {
            WatchedToggleButton(entry: entry, model: model)
                .tint(.accentColor)
        }
        .swipeActions(edge: .trailing) {
            RemoveEntryButton(entry: entry, model: model)
        }
        .accessibilityLabel(entry.accessibilityLabel)
        .accessibilityHint("Plays the video")
    }

    private func open() {
        onOpen(entry.item)
    }
}
