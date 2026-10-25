import DesignSystem
import Domain
import SwiftUI

struct PosterCard: View {
    let entry: LibraryEntry
    let model: LibraryModel
    let onOpen: (MediaItem) -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: Metrics.controlSpacing) {
                PosterImage(item: entry.item, model: model, cornerRadius: Metrics.posterCornerRadius)
                    .overlay(alignment: .bottom) {
                        EntryProgressBar(fraction: entry.watchedFraction ?? 0)
                            .padding(Metrics.controlSpacing)
                            .opacity(entry.watchedFraction == nil ? 0 : 1)
                    }
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .tint)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .padding(Metrics.controlSpacing)
                            .opacity(entry.isWatched ? 1 : 0)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    EntryStatusText(entry: entry)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleOnly)
                }
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
