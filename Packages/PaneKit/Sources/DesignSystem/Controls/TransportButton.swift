import SwiftUI

/// An icon-only control sized to the minimum hit target. Meant to sit inside a glass container rather than carry its own glass.
public struct TransportButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let action: () -> Void

    @ScaledMetric(relativeTo: .title3) private var size = Metrics.minimumHitTarget

    public init(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.transportSymbol)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .contentShape(.circle)
        }
        .buttonStyle(TransportButtonStyle())
    }
}

private struct TransportButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.86 : 1)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
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
