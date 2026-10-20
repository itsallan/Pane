import DesignSystem
import Domain
import SwiftUI

struct PosterCard: View {
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
                            .opacity(entry.watchedFraction == nil ? 0 : 1)
                    }
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .tint)
                            .padding(8)
                            .opacity(entry.isWatched ? 1 : 0)
                    }
                Text(entry.item.title)
                    .font(.subheadline)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu {
            EntryActions(entry: entry, model: model, onOpen: onOpen)
        }
        .accessibilityLabel(entry.accessibilityLabel)
        .accessibilityHint("Plays the video")
    }

    private func open() {
        onOpen(entry.item)
    }
}
