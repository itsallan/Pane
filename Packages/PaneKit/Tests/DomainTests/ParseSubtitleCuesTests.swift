import Domain
import Testing

struct ParseSubtitleCuesTests {
    private let parse = ParseSubtitleCues()

    @Test func readsSRT() {
        let srt = """
        1
        00:00:01,500 --> 00:00:03,000
        <i>Hello</i>
        there

        2
        01:02:03,045 --> 01:02:05,000
        Second
        """
        let cues = parse(srt.replacing("\n", with: "\r\n"))
        #expect(cues == [
            SubtitleCue(id: 0, start: .milliseconds(1500), end: .seconds(3), text: "Hello\nthere"),
            SubtitleCue(id: 1, start: .seconds(3723) + .milliseconds(45), end: .seconds(3725), text: "Second"),
        ])
    }

    @Test func readsWebVTTWithoutHours() {
        let vtt = """
        WEBVTT

        intro
        00:05.250 --> 00:07.000 align:start
        <c.yellow>Hi</c>
        """
        #expect(parse(vtt) == [SubtitleCue(id: 0, start: .milliseconds(5250), end: .seconds(7), text: "Hi")])
    }

    @Test func readsASSDialogueAndSortsByStart() {
        let ass = """
        [Script Info]
        Title: Test

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:10.50,0:00:12.00,Default,,0,0,0,,{\\an8}Later, with a comma
        Dialogue: 0,0:00:02.00,0:00:04.00,Default,,0,0,0,,First\\Nline
        """
        let cues = parse(ass)
        #expect(cues.map(\.text) == ["First\nline", "Later, with a comma"])
        #expect(cues.map(\.start) == [.seconds(2), .milliseconds(10500)])
        #expect(cues.map(\.id) == [0, 1])
    }

    @Test func skipsGarbage() {
        #expect(parse("not a subtitle\n--> nothing\n").isEmpty)
    }
}
