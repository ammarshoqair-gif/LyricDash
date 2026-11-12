import Foundation

struct LyricLine: Sendable {
    let time: Double   // seconds from the start of the song
    let text: String
}

/// Turns synced lyrics like "[01:23.45] Some line" into timed lines.
enum LRCParser {
    static func parse(_ lrc: String) -> [LyricLine] {
        guard let regex = try? NSRegularExpression(pattern: #"\[(\d+):(\d+(?:\.\d+)?)\]"#) else {
            return []
        }
        var result: [LyricLine] = []
        for raw in lrc.components(separatedBy: .newlines) {
            let ns = raw as NSString
            let full = NSRange(location: 0, length: ns.length)
            let matches = regex.matches(in: raw, range: full)
            guard !matches.isEmpty else { continue }
            let text = regex
                .stringByReplacingMatches(in: raw, range: full, withTemplate: "")
                .trimmingCharacters(in: .whitespaces)
            for match in matches {
                let minutes = Double(ns.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(ns.substring(with: match.range(at: 2))) ?? 0
                result.append(LyricLine(time: minutes * 60 + seconds, text: text))
            }
        }
        return result.sorted { $0.time < $1.time }
    }
}
