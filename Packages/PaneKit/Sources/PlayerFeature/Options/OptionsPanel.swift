import SwiftUI

struct OptionsPanel: View {
    let model: PlayerModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SpeedSection(model: model)
                VolumeSection(model: model)
                if model.isSeekable {
                    LoopSection(loop: model.loop)
                }
                PictureSection(model: model)
                if !model.chapters.isEmpty {
                    ChapterSection(model: model)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 300, idealWidth: 340, maxHeight: 480)
    }
}
