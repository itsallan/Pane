#if os(iOS)
import SwiftUI

/// A glass sheet over the video. The medium detent keeps the picture in view while you adjust it.
struct OptionsSheet: View {
    let model: PlayerModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            OptionsPanel(model: model)
                // The sheet's own glass is the background; the grouped form would otherwise paint over it.
                .scrollContentBackground(.hidden)
                .navigationTitle("Playback")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark", role: .confirm, action: dismiss.callAsFunction)
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}
#endif
