#if os(macOS)
import Domain
import LibraryFeature
import PlayerFeature
import SwiftUI
import UniformTypeIdentifiers

// Bare keys work as menu key equivalents, and AppKit offers them to the menu before the window,
// so these are the player's only keyboard handling. A disabled item lets the key through, which is
// why everything turns off while the options popover or track sheet has the keyboard.
struct PlaybackCommands: Commands {
    let dependencies: AppDependencies

    @FocusedValue(\.player) private var player
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open…", action: showOpenPanel)
                .keyboardShortcut("o")
            Button("Open URL…") {
                openWindow(id: OpenURLWindow.id)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }
        CommandMenu("Playback") {
            Button(model?.isPlaybackActive == true ? "Pause" : "Play") {
                model?.togglePlayback()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(model == nil)
            Divider()
            Button("Skip Back 10 Seconds") {
                model?.skip(by: .zero - PlayerModel.skipInterval)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(model?.isSeekable != true)
            Button("Skip Forward 10 Seconds") {
                model?.skip(by: PlayerModel.skipInterval)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(model?.isSeekable != true)
            Button("Next Frame") {
                model?.stepFrame()
            }
            .keyboardShortcut(".", modifiers: [])
            .disabled(model?.canStepFrame != true)
            Divider()
            Button("Rewind") {
                model?.shuttleBackward()
            }
            .keyboardShortcut("j", modifiers: [])
            .disabled(model?.isSeekable != true)
            Button("Stop Shuttle") {
                model?.shuttleStop()
            }
            .keyboardShortcut("k", modifiers: [])
            .disabled(model == nil)
            Button("Fast Forward") {
                model?.shuttleForward()
            }
            .keyboardShortcut("l", modifiers: [])
            .disabled(model == nil)
            Divider()
            Button("Slower") {
                model?.slowDown()
            }
            .keyboardShortcut("[", modifiers: [])
            .disabled(model?.canSlowDown != true)
            Button("Faster") {
                model?.speedUp()
            }
            .keyboardShortcut("]", modifiers: [])
            .disabled(model?.canSpeedUp != true)
            Divider()
            Button("Volume Up") {
                model?.raiseVolume()
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            .disabled(model == nil)
            Button("Volume Down") {
                model?.lowerVolume()
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            .disabled(model == nil)
            Divider()
            Button(player?.isFullScreen == true ? "Exit Full Screen" : "Enter Full Screen") {
                player?.toggleFullScreen()
            }
            .keyboardShortcut("f", modifiers: [])
            .disabled(model == nil)
        }
    }

    private var model: PlayerModel? {
        guard let model = player?.model, !model.isMenuPresented, !model.isTrackSheetPresented else { return nil }
        return model
    }

    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = UTType.playableMedia
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        Task {
            guard await panel.begin() == .OK else { return }
            let items = await dependencies.importForOpening(panel.urls)
            dependencies.libraryDidChange()
            for item in items {
                openWindow(id: PlayerWindow.id, value: item.id)
            }
        }
    }
}
#endif
