import DesignSystem
import Domain
import SwiftUI

struct ChapterRow: View {
    let chapter: Chapter
    let isCurrent: Bool
    let onSelect: (Chapter) -> Void

    var body: some View {
        Button(action: select) {
            HStack {
                Text(chapter.displayName)
                Spacer()
                Text(chapter.start.timecode)
                    .font(.timecode)
                    .foregroundStyle(.secondary)
                Image(systemName: "checkmark")
                    .opacity(isCurrent ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Metrics.minimumHitTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func select() {
        onSelect(chapter)
    }
}
