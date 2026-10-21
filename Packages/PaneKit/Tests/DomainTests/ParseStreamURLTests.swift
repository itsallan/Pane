import Domain
import Foundation
import Testing

struct ParseStreamURLTests {
    private let parse = ParseStreamURL()

    @Test(arguments: [
        "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
        "http://192.168.1.20:8080/live",
        "rtsp://camera.local:554/stream1",
        "  HTTPS://example.com/movie.mp4\n",
    ])
    func acceptsStreams(_ text: String) throws {
        let url = try parse(text)
        #expect(url.absoluteString == text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test func assumesHTTPSWithoutAScheme() throws {
        #expect(try parse("example.com/live.m3u8") == URL(string: "https://example.com/live.m3u8"))
    }

    @Test func rejectsEmptyText() {
        #expect(throws: StreamURLError.empty) { try parse("   ") }
    }

    @Test func rejectsSchemesVLCShouldNotOpenFromHere() {
        #expect(throws: StreamURLError.unsupportedScheme("file")) { try parse("file://localhost/etc/hosts") }
        #expect(throws: StreamURLError.unsupportedScheme("smb")) { try parse("smb://nas.local/Movies") }
    }

    @Test func rejectsMalformedText() {
        #expect(throws: StreamURLError.malformed) { try parse("http://") }
        #expect(throws: StreamURLError.malformed) { try parse("not a url at all") }
    }

    @Test func refusesLinksWithPasswords() {
        #expect(throws: StreamURLError.containsPassword) { try parse("http://user:secret@example.com/live") }
    }
}
