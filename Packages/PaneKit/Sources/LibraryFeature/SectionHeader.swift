import DesignSystem
import SwiftUI

struct SectionHeader: View {
    private let title: LocalizedStringKey
    private let detail: Text?

    init(_ title: LocalizedStringKey, detail: Text? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Metrics.controlSpacing)
            if let detail {
                detail
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Metrics.edgeInset)
    }
}
