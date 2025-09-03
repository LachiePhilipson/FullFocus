import SwiftUI

/// Compact, width-stable relative time label for menu rows.
struct TimeRemainingLabel: View {
    let startDate: Date
    private let reference: String = "in 88h 88m"

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let interval = startDate.timeIntervalSince(context.date)
            let (text, color) = display(for: interval)

            ZStack(alignment: .leading) {
                Text(reference)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .opacity(0)
                Text(text)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(color)
            }
            .transaction { $0.disablesAnimations = true }
        }
    }

    private func display(for interval: TimeInterval) -> (String, Color) {
        let color = EventTimingPalette.color(for: interval)
        if interval <= 0 { return ("Now", color) }
        let minutes = Int(interval / 60)
        if minutes < 60 { return ("in \(minutes)m", color) }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins > 0 { return (String(format: "in %dh %02dm", hours, mins), color) }
        else { return ("in \(hours)h", color) }
    }
}

