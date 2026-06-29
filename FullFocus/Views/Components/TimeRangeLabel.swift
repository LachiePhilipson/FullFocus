import SwiftUI

/// Formats a compact time range such as “12 – 1:30 PM”.
struct TimeRangeLabel: View {
    let startDate: Date
    let endDate: Date

    private static let formatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        let formattedRange = Self.formatter.string(from: startDate, to: endDate)
        Text(formattedRange)
            .monospacedDigit()
            .accessibilityLabel(formattedRange)
            .transaction { $0.disablesAnimations = true }
    }
}
