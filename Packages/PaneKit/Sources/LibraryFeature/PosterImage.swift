import DesignSystem
import Domain
import SwiftUI

/// Shows a generated frame, or a placeholder while it's made or when the file can't be decoded.
struct PosterImage: View {
    let item: MediaItem
    let model: LibraryModel
    let cornerRadius: CGFloat

    @State private var url: URL?

    var body: some View {
        PosterPlaceholder(title: item.title)
            .overlay {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.clear
                }
            }
            .aspectRatio(Metrics.posterAspectRatio, contentMode: .fit)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .accessibilityHidden(true)
            .task(id: item.source) {
                url = await model.poster(for: item)
            }
    }
}
