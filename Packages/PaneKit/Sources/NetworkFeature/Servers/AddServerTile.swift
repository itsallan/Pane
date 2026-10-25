import DesignSystem
import SwiftUI

/// Sits at the end of the saved servers, so adding one is obvious even before anything is saved.
struct AddServerTile: View {
    let action: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var minimumHeight = Metrics.tileMinimumHeight - Metrics.tilePadding * 2

    var body: some View {
        Button(action: action) {
            VStack(spacing: Metrics.controlSpacing) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .accessibilityHidden(true)
                Text("Add Server")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity, minHeight: minimumHeight)
            .padding(Metrics.tilePadding)
            .background {
                RoundedRectangle(cornerRadius: Metrics.tileCornerRadius)
                    .strokeBorder(.tint.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .contentShape(.rect(cornerRadius: Metrics.tileCornerRadius))
        }
        .buttonStyle(.plain)
    }
}
