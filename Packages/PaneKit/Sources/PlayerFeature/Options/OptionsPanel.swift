import SwiftUI

/// Only what you change while watching. Preferences that outlive this video live in Settings.
struct OptionsPanel: View {
    let model: PlayerModel

    var body: some View {
        Form {
            SpeedSection(model: model)
            VolumeSection(model: model)
            PictureSection(model: model)
            if !model.areSubtitlesOff {
                SubtitleTimingSection(sync: model.subtitleSync, onSyncByEar: syncByEar)
            }
            if model.isSeekable {
                LoopSection(loop: model.loop)
            }
            SleepTimerSection(timer: model.sleepTimer)
            if !model.chapters.isEmpty {
                ChapterSection(model: model)
            }
        }
        .formStyle(.grouped)
    }

    private func syncByEar() {
        model.isMenuPresented = false
        model.subtitleSync.begin()
    }
}
