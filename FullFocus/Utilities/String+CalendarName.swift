import Foundation

extension String {
    /// Normalizes calendar titles by replacing nonbreaking spaces and trimming whitespace.
    var cleanedCalendarName: String {
        let replaced = self.replacingOccurrences(of: "\u{00A0}", with: " ")
        return replaced.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

