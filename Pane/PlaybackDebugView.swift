#if DEBUG
import Domain
import Playback
import SwiftUI

struct PlaybackDebugView: View {
    private enum Sample: String, CaseIterable, Identifiable {
        case hls = "BBB HLS"
        case mkv = "MKV subs"

        var id: Self { self }

        var url: URL {
            switch self {
            case .hls: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!
            case .mkv: URL(string: "https://raw.githubusercontent.com/ietf-wg-cellar/matroska-test-files/master/test_files/test5.mkv")!
            }
        }
    }

    // Created on first appear, not in the initializer, which SwiftUI may run many times.
    @State private var session: (engine: VLCPlaybackEngine, drawable: VideoDrawable)?
    @State private var state = PlaybackState()
    @State private var sample = Sample.hls
    @State private var thumbnail: URL?
    @State private var thumbnailStatus = ""
    private let thumbnails = VLCThumbnailProvider()

    var body: some View {
        Group {
            if let session {
                controls(session.engine, drawable: session.drawable)
            } else {
                Color.black
            }
        }
        .onAppear {
            if session == nil {
                session = VLCPlaybackEngine.makeWithSurface()
            }
        }
        .onDisappear {
            let engine = session?.engine
            Task { await engine?.close() }
        }
    }

    private func controls(_ engine: VLCPlaybackEngine, drawable: VideoDrawable) -> some View {
        VStack(spacing: 12) {
            VideoSurface(drawable)
                .aspectRatio(16 / 9, contentMode: .fit)

            Picker("Sample", selection: $sample) {
                ForEach(Sample.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Text(summary)
                .font(.caption.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("-10s") { Task { await engine.seek(by: .seconds(-10)) } }
                Button(state.status == .playing ? "Pause" : "Play") {
                    Task { state.status == .playing ? await engine.pause() : await engine.play() }
                }
                Button("+10s") { Task { await engine.seek(by: .seconds(10)) } }
                Button("Sub") { Task { await cycleSubtitle(engine) } }
                Button("Thumb") { Task { await loadThumbnail() } }
            }
            .buttonStyle(.bordered)

            Text(thumbnailStatus)
                .font(.caption.monospaced())
            if let thumbnail {
                AsyncImage(url: thumbnail) { $0.resizable().scaledToFit() } placeholder: { ProgressView() }
                    .frame(height: 80)
            }
            Spacer()
        }
        .padding()
        .task {
            for await next in engine.states() {
                state = next
            }
        }
        .task(id: sample) {
            // Seeks before the media is open, to exercise the pending-seek path.
            try? await engine.load(.stream(sample.url))
            await engine.seek(to: .seconds(20), precision: .exact)
        }
    }

    private var summary: String {
        let position = state.progress.position.formatted(.time(pattern: .minuteSecond))
        let duration = state.progress.duration?.formatted(.time(pattern: .minuteSecond)) ?? "--"
        let subtitles = state.tracks.filter { $0.kind == .subtitle }
        let selected = state.tracks.filter { state.selectedTrackIDs.contains($0.id) }.map { $0.title ?? $0.id }
        return """
        \(state.status)  \(position) / \(duration)  seekable: \(state.isSeekable)
        size: \(state.videoSize.map { "\($0.width)x\($0.height)" } ?? "-")  chapters: \(state.chapters.count)
        audio: \(state.tracks.count { $0.kind == .audio })  subtitles: \(subtitles.count)
        selected: \(selected.joined(separator: ", "))
        """
    }

    private func cycleSubtitle(_ engine: VLCPlaybackEngine) async {
        let subtitles = state.tracks.filter { $0.kind == .subtitle }
        let current = subtitles.firstIndex { state.selectedTrackIDs.contains($0.id) }
        let next = current.map { $0 + 1 } ?? 0
        if next < subtitles.count {
            try? await engine.selectTrack(subtitles[next].id)
        } else {
            await engine.deselectTrack(kind: .subtitle)
        }
    }

    private func loadThumbnail() async {
        thumbnailStatus = "thumb: loading"
        let start = ContinuousClock.now
        do {
            thumbnail = try await thumbnails.thumbnail(for: .stream(sample.url), at: .seconds(32), maxPixelSize: 320)
            thumbnailStatus = "thumb: \(thumbnail?.lastPathComponent.suffix(16) ?? "") in \(ContinuousClock.now - start)"
        } catch {
            thumbnailStatus = "thumb: \(error) after \(ContinuousClock.now - start)"
        }
    }
}
#endif
