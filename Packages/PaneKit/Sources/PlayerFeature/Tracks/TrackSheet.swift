import Domain
import SwiftUI

struct TrackSheet: View {
    @Bindable var model: PlayerModel

    @Environment(\.dismiss) private var dismiss
    @State private var isImporterPresented = false

    var body: some View {
        NavigationStack {
            List {
                if !model.audioTracks.isEmpty {
                    Section("Audio") {
                        ForEach(model.audioTracks) { track in
                            TrackRow(title: track.displayName, detail: track.detail, isSelected: model.selectedTrackIDs.contains(track.id)) {
                                model.selectTrack(track)
                            }
                        }
                    }
                }
                Section {
                    TrackRow(title: String(localized: "Off"), isSelected: model.areSubtitlesOff, action: model.turnOffSubtitles)
                    ForEach(model.subtitleTracks) { track in
                        TrackRow(title: track.displayName, detail: track.detail, isSelected: model.selectedTrackIDs.contains(track.id)) {
                            model.selectTrack(track)
                        }
                    }
                    Button("Add Subtitle File…", systemImage: "plus", action: presentImporter)
                } header: {
                    Text("Subtitles")
                } footer: {
                    Text("Timing is under Playback Options. Style and preferred languages are in Settings.")
                }
            }
            .navigationTitle("Audio & Subtitles")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: SubtitleFile.contentTypes, onCompletion: importSubtitle)
        .alert("This subtitle file can't be read.", isPresented: $model.subtitleImportFailed) {}
        .presentationDetents([.medium, .large])
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 420)
        #endif
    }

    private func presentImporter() {
        isImporterPresented = true
    }

    private func importSubtitle(_ result: Result<URL, any Error>) {
        guard case .success(let url) = result else {
            model.subtitleImportFailed = true
            return
        }
        Task { await model.addSubtitle(from: url) }
    }
}
