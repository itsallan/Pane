import DesignSystem
import SwiftUI

struct SnapshotToast: View {
    let outcome: FrameSnapshot.Outcome

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
            .accessibilityAddTraits(.isStaticText)
    }

    private var title: LocalizedStringKey {
        switch outcome {
        case .saved: "Saved to Photos"
        case .accessDenied: "Allow Pane to add photos in Settings"
        case .failed: "Couldn't save the frame"
        }
    }

    private var symbol: String {
        switch outcome {
        case .saved: "checkmark.circle.fill"
        case .accessDenied: "lock.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
}
