import Foundation

/// Gets synced lyrics from LRCLIB (https://lrclib.net), a free community lyrics database.
enum LyricsService {
    private struct Track: Decodable {
        let duration: Double?
        let syncedLyrics: String?
    }

    /// Tries an exact match first, then looser searches.
    /// Always prefers the version whose length matches the song that's playing,
    /// because different versions of a song have different timing.
    static func fetch(title: String, artist: String, duration: Double) async -> [LyricLine]? {
        let shortTitle = clean(title)
        let mainArtist = firstArtist(artist)

        // 1) Exact match on title + artist + song length
        if duration > 0 {
            let exact = [
                URLQueryItem(name: "track_name", value: title),
                URLQueryItem(name: "artist_name", value: artist),
                URLQueryItem(name: "duration", value: String(Int(duration.rounded()))),
            ]
            if let hit = await get("get", exact, Track.self), let lines = parsed(hit) {
                return lines
            }
        }

        // 2) Looser searches (handles "feat." titles, remasters, multiple artists)
        var searches: [[URLQueryItem]] = [[
            URLQueryItem(name: "track_name", value: shortTitle),
            URLQueryItem(name: "artist_name", value: artist),
        ]]
        if mainArtist != artist {
            searches.append([
                URLQueryItem(name: "track_name", value: shortTitle),
                URLQueryItem(name: "artist_name", value: mainArtist),
            ])
        }
        searches.append([URLQueryItem(name: "q", value: shortTitle + " " + mainArtist)])

        for query in searches {
            if Task.isCancelled { return nil }
            if let hits = await get("search", query, [Track].self),
               let best = bestMatch(hits, duration: duration),
               let lines = parsed(best) {
                return lines
            }
        }
        return nil
    }

    // MARK: Helpers

    private static func parsed(_ track: Track) -> [LyricLine]? {
        guard let synced = track.syncedLyrics, !synced.isEmpty else { return nil }
        let lines = LRCParser.parse(synced)
        return lines.isEmpty ? nil : lines
    }

    /// Picks the result closest in length to the playing song (within 10 seconds).
    private static func bestMatch(_ hits: [Track], duration: Double) -> Track? {
        let synced = hits.filter { ($0.syncedLyrics ?? "").isEmpty == false }
        guard duration > 0 else { return synced.first }

        var best: Track?
        var bestGap = Double.greatestFiniteMagnitude
        for hit in synced {
            guard let length = hit.duration else { continue }
            let gap = abs(length - duration)
            if gap < bestGap {
                best = hit
                bestGap = gap
            }
        }
        return bestGap <= 10 ? best : nil
    }

    /// "Song (feat. X) - Remastered" -> "Song"
    private static func clean(_ title: String) -> String {
        var short = title
        for marker in [" (", " [", " - "] {
            if let range = short.range(of: marker) {
                short = String(short[..<range.lowerBound])
            }
        }
        return short.trimmingCharacters(in: .whitespaces)
    }

    /// "Artist A, Artist B & Artist C" -> "Artist A"
    private static func firstArtist(_ artist: String) -> String {
        var first = artist
        for marker in [", ", " & ", " feat", " ft.", " x ", " X "] {
            if let range = first.range(of: marker) {
                first = String(first[..<range.lowerBound])
            }
        }
        return first.trimmingCharacters(in: .whitespaces)
    }

    private static func get<T: Decodable>(_ endpoint: String, _ query: [URLQueryItem], _ type: T.Type) async -> T? {
        guard var parts = URLComponents(string: "https://lrclib.net/api/" + endpoint) else { return nil }
        parts.queryItems = query
        // A "+" in a song title must be sent as %2B, or the server reads it as a space.
        parts.percentEncodedQuery = parts.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = parts.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("LyricDash/1.1 (personal project)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
