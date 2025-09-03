import Foundation

struct MeetingURLDetector {
    // Precompiled patterns; keep small and focused for reliability
    private static let patterns: [NSRegularExpression] = {
        let raw: [String] = [
            #"https?://[^\s<>\"{}|\\^\[\]`]+"#,
            #"(?:zoom\.us|meet\.google\.com|teams\.microsoft\.com|webex\.com)/[^\s<>\"{}|\\^\[\]`]+"#,
        ]
        return raw.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    static func detect(location: String?, notes: String?) -> URL? {
        for candidate in [location, notes].compactMap({ $0 }) {
            if let url = detect(in: candidate) { return url }
        }
        return nil
    }

    static func detect(in string: String) -> URL? {
        let text = string
        for regex in patterns {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                var urlString = String(text[range])
                urlString = urlString.trimmingCharacters(in: CharacterSet(charactersIn: ")].,;:!\"'"))
                if !urlString.lowercased().hasPrefix("http") {
                    urlString = "https://" + urlString
                }
                return URL(string: urlString)
            }
        }
        return nil
    }
}

#if DEBUG
extension MeetingURLDetector {
    static func selfTest() {
        assert(detect(in: "Join: https://zoom.us/j/123?pwd=abc") != nil)
        assert(detect(in: "meet.google.com/abc-defg-hij") != nil)
        assert(detect(in: "teams.microsoft.com/l/meetup-join/12345.") != nil)
        assert(detect(in: "(webex.com/meet/room)") != nil)
        assert(detect(location: nil, notes: nil) == nil)
    }
}
#endif

