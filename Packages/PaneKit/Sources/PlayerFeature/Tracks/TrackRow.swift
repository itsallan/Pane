import SwiftUI

struct TrackRow: View {
    let title: String
    var detail: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
