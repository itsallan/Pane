import SwiftUI

/// A bold title over a scrolling section, with an optional note on the trailing side.
public struct SectionHeader<Detail: View>: View {
    private let title: LocalizedStringKey
    private let detail: Detail

    public init(_ title: LocalizedStringKey, @ViewBuilder detail: () -> Detail) {
        self.title = title
        self.detail = detail()
    }

    public var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Metrics.controlSpacing)
            detail
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Metrics.edgeInset)
    }
}

extension SectionHeader where Detail == EmptyView {
    public init(_ title: LocalizedStringKey) {
        self.init(title) { EmptyView() }
    }
}
