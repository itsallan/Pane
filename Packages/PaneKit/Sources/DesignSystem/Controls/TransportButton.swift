import SwiftUI

/// An icon-only control at least the minimum hit target in size. Meant to sit inside a glass container rather than carry its own glass.
public struct TransportButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let symbolFont: Font
    private let action: () -> Void

    @ScaledMetric private var size: CGFloat

    public init(
        _ title: LocalizedStringKey,
        systemImage: String,
        diameter: CGFloat = Metrics.minimumHitTarget,
        symbolFont: Font = .transportSymbol,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.symbolFont = symbolFont
        self.action = action
        _size = ScaledMetric(wrappedValue: max(diameter, Metrics.minimumHitTarget), relativeTo: .title3)
    }

    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(symbolFont)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .contentShape(.circle)
        }
        .buttonStyle(.transport)
    }
}

/// Shrinks and dims while pressed, without the bounce under Reduce Motion.
public struct TransportButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.86 : 1)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == TransportButtonStyle {
    public static var transport: TransportButtonStyle { TransportButtonStyle() }
}

#Preview {
    HStack {
        TransportButton("Play", systemImage: "play.fill") {}
        TransportButton("Skip Forward", systemImage: "goforward.10") {}
    }
    .padding(8)
    .glassEffect(.regular, in: .capsule)
    .padding()
}
