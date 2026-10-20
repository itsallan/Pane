import DesignSystem
import SwiftUI

/// The ripple shown after a double tap. Consecutive taps on the same side add up.
struct SeekFeedback: Identifiable, Equatable {
    enum Side {
        case leading
        case trailing
    }

    let id = UUID()
    var side: Side
    var location: CGPoint
    var seconds: Int
}

struct SeekFeedbackView: View {
    let feedback: SeekFeedback

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let isLeading = feedback.side == .leading
            ZStack {
                Ellipse()
                    .fill(.white.opacity(0.12))
                    .frame(width: proxy.size.width, height: proxy.size.height * 1.6)
                    .offset(x: isLeading ? -proxy.size.width * 0.55 : proxy.size.width * 0.55)
                if !reduceMotion {
                    Circle()
                        .fill(.white.opacity(isExpanded ? 0 : 0.3))
                        .frame(width: 80, height: 80)
                        .scaleEffect(isExpanded ? 4 : 0.4)
                        .position(feedback.location)
                }
                Label {
                    Text("\(feedback.seconds) s")
                } icon: {
                    Image(systemName: isLeading ? "gobackward" : "goforward")
                }
                .labelStyle(.vertical)
                .font(.indicatorValue)
                .foregroundStyle(.white)
                .position(x: proxy.size.width * (isLeading ? 0.22 : 0.78), y: proxy.size.height / 2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { isExpanded = true }
        }
    }
}

private struct VerticalLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 6) {
            configuration.icon
            configuration.title
        }
    }
}

private extension LabelStyle where Self == VerticalLabelStyle {
    static var vertical: VerticalLabelStyle { VerticalLabelStyle() }
}
