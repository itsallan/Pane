import Foundation

public enum StreamURLError: Error, Sendable, Hashable {
    case empty
    case malformed
    case unsupportedScheme(String)
    /// The link carries a password, which would end up in the library and history in plain text.
    case containsPassword
}

/// Turns what the user typed into a stream URL VLC can open, or says why it can't.
public struct ParseStreamURL: Sendable {
    public static let supportedSchemes: Set<String> = ["http", "https", "rtsp", "rtsps", "rtmp", "rtmps", "rtp", "udp", "mms", "mmsh"]

    public init() {}

    public func callAsFunction(_ text: String) throws(StreamURLError) -> URL {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }
        // People paste "example.com/live.m3u8" without a scheme; that's almost always http(s), and https is the safe guess.
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: candidate), let scheme = components.scheme?.lowercased(),
              let host = components.host, !host.isEmpty, let url = components.url else {
            throw .malformed
        }
        guard Self.supportedSchemes.contains(scheme) else { throw .unsupportedScheme(scheme) }
        guard components.password == nil else { throw .containsPassword }
        return url
    }
}
