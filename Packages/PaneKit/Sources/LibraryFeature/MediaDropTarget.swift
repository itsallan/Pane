import DesignSystem
import SwiftUI
import UniformTypeIdentifiers

struct MediaDropTarget: ViewModifier {
    let isEnabled: Bool
    let onDrop: ([URL]) -> Void

    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            #if os(macOS)
            // Finder hands over the original URLs with sandbox access already granted.
            .dropDestination(for: URL.self) { urls, _ in
                accept(urls.filter(\.isFileURL))
            } isTargeted: { targeted in
                isTargeted = targeted
            }
            #else
            .onDrop(of: UTType.playableMedia + [.folder], isTargeted: $isTargeted, perform: accept)
            #endif
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.posterCornerRadius)
                    .strokeBorder(.tint, lineWidth: 3)
                    .padding(4)
                    .opacity(isEnabled && isTargeted ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }

    private func accept(_ urls: [URL]) -> Bool {
        guard isEnabled, !urls.isEmpty else { return false }
        onDrop(urls)
        return true
    }

    #if os(iOS)
    private func accept(_ providers: [NSItemProvider]) -> Bool {
        guard isEnabled else { return false }
        Task {
            var urls: [URL] = []
            for provider in providers {
                if let url = await DroppedFile.load(from: provider) {
                    urls.append(url)
                }
            }
            onDrop(urls)
        }
        return true
    }
    #endif
}
