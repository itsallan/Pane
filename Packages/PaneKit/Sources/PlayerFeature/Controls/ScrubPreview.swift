import DesignSystem
import ImageIO
import SwiftUI

struct ScrubPreview: View {
    let thumbnail: URL?
    let position: Duration
    let chapterTitle: String?

    @ScaledMetric(relativeTo: .caption) private var width = 168.0

    var body: some View {
        VStack(spacing: 6) {
            ThumbnailImage(url: thumbnail)
                .frame(width: width, height: width * 9 / 16)
                .clipShape(.rect(cornerRadius: 12))
            VStack(spacing: 2) {
                if let chapterTitle {
                    Text(chapterTitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(position.timecode)
                    .font(.timecode)
            }
            .frame(maxWidth: width)
        }
        .padding(6)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

/// Holds the last decoded frame until the next one arrives, so scrubbing never flashes a placeholder.
private struct ThumbnailImage: View {
    let url: URL?

    @State private var image: CGImage?

    var body: some View {
        ZStack {
            Color.mediaBackground.opacity(0.6)
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            }
        }
        .task(id: url) {
            guard let url, let decoded = await Self.decode(url) else { return }
            image = decoded
        }
    }

    @concurrent
    private static func decode(_ url: URL) async -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
