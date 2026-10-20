import DesignSystem
import SwiftUI

struct SectionHeader: View {
    private let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.title2)
            .bold()
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, Metrics.edgeInset)
    }
}
