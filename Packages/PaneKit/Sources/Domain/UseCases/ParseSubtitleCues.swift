import Foundation

/// Reads the cues of an SRT, WebVTT, ASS or SSA file. The engine renders subtitles itself; this is only for
/// features that need the lines, like syncing by ear.
public struct ParseSubtitleCues: Sendable {
    public init() {}

    public func callAsFunction(_ contents: String) -> [SubtitleCue] {
        let lines = contents.replacing("\r\n", with: "\n").replacing("\r", with: "\n").split(separator: "\n", omittingEmptySubsequences: false)
        let isASS = lines.contains { $0.trimmingCharacters(in: .whitespaces).lowercased() == "[events]" }
        return (isASS ? Self.assCues(in: lines) : Self.timedBlockCues(in: lines))
            .sorted { $0.start < $1.start }
            .enumerated()
            .map { SubtitleCue(id: $0.offset, start: $0.element.start, end: $0.element.end, text: $0.element.text) }
    }
}

private extension ParseSubtitleCues {
    typealias Timing = (start: Duration, end: Duration, text: String)

    // SRT and WebVTT share the shape that matters: a "start --> end" line followed by text up to a blank line.
    static func timedBlockCues(in lines: [Substring]) -> [Timing] {
        var cues: [Timing] = []
        var index = lines.startIndex
        while index < lines.endIndex {
            let line = lines[index]
            index += 1
            guard let arrow = line.range(of: "-->"),
                  let start = timestamp(line[..<arrow.lowerBound]),
                  let end = timestamp(line[arrow.upperBound...].split(separator: " ", omittingEmptySubsequences: true).first ?? "")
            else { continue }
            var text: [Substring] = []
            while index < lines.endIndex, !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                text.append(lines[index])
                index += 1
            }
            let cleaned = text.map { stripMarkup(String($0)) }.joined(separator: "\n")
            if !cleaned.isEmpty {
                cues.append((start, end, cleaned))
            }
        }
        return cues
    }

    static func assCues(in lines: [Substring]) -> [Timing] {
        var fields = ["layer", "start", "end", "style", "name", "marginl", "marginr", "marginv", "effect", "text"]
        var cues: [Timing] = []
        for line in lines {
            if line.hasPrefix("Format:") {
                fields = line.dropFirst("Format:".count).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                continue
            }
            guard line.hasPrefix("Dialogue:"),
                  let startIndex = fields.firstIndex(of: "start"),
                  let endIndex = fields.firstIndex(of: "end"),
                  fields.last == "text"
            else { continue }
            // Text is the last field and may itself contain commas.
            let values = line.dropFirst("Dialogue:".count).split(separator: ",", maxSplits: fields.count - 1, omittingEmptySubsequences: false)
            guard values.count == fields.count,
                  let start = timestamp(values[startIndex]),
                  let end = timestamp(values[endIndex])
            else { continue }
            let text = stripMarkup(String(values[values.count - 1]).replacing("\\N", with: "\n").replacing("\\n", with: "\n"))
            if !text.isEmpty {
                cues.append((start, end, text))
            }
        }
        return cues
    }

    /// Accepts `01:02:03,456` (SRT), `01:02:03.456` or `02:03.456` (WebVTT) and `1:02:03.45` (ASS).
    static func timestamp(_ text: Substring) -> Duration? {
        let parts = text.trimmingCharacters(in: .whitespaces).replacing(",", with: ".").split(separator: ":")
        guard (2...3).contains(parts.count), let seconds = Double(parts[parts.count - 1]) else { return nil }
        let units = parts.dropLast().compactMap { Int($0) }
        guard units.count == parts.count - 1 else { return nil }
        let minutes = units.reduce(0) { $0 * 60 + $1 }
        return .seconds(minutes * 60) + .milliseconds(Int((seconds * 1000).rounded()))
    }

    // Drops HTML-style tags (<i>, <c.yellow>) and ASS override blocks ({\an8}).
    static func stripMarkup(_ text: String) -> String {
        text
            .replacing(#/<[^>]*>/#, with: "")
            .replacing(#/\{[^}]*\}/#, with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
