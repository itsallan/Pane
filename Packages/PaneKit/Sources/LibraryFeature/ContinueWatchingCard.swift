import DesignSystem
import Domain
import SwiftUI

/// Artwork edge to edge with the title, time left and progress laid over it, like a resume tile on Apple TV.
struct ContinueWatchingCard: View {
    let entry: LibraryEntry
    let model: LibraryModel
    let onOpen: (MediaItem) -> Void

    var body: some View {
        Button(action: open) {
            PosterImage(item: entry.item, model: model, cornerRadius: Metrics.heroCornerRadius)
                .overlay {
                    Rectangle()
                        .fill(.artworkScrim)
                        .clipShape(.rect(cornerRadius: Metrics.heroCornerRadius))
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.item.title)
                            .font(.headline)
                            .lineLimit(1)
                        EntryStatusText(entry: entry)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                        EntryProgressBar(fraction: entry.watchedFraction ?? 0)
                            .padding(.top, 2)
                    }
                    .foregroundStyle(.white)
                    .padding(Metrics.edgeInset)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "play.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: Metrics.badgeSize, height: Metrics.badgeSize)
                        // Tinted dark whatever the appearance, since it always sits on artwork.
                        .glassEffect(.regular.tint(.black.opacity(0.35)), in: .circle)
                        .padding(Metrics.controlSpacing + 4)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect(cornerRadius: Metrics.heroCornerRadius))
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
