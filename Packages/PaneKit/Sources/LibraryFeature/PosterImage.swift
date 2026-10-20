import DesignSystem
import Domain
import SwiftUI

/// Shows a generated frame, or a placeholder while it's made or when the file can't be decoded.
struct PosterImage: View {
    let item: MediaItem
    let model: LibraryModel

    @State private var url: URL?

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "film")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .aspectRatio(Metrics.posterAspectRatio, contentMode: .fit)
            .clipShape(.rect(cornerRadius: Metrics.posterCornerRadius))
            .accessibilityHidden(true)
            .task(id: item.source) {
                url = await model.poster(for: item)
            }
    }
}
