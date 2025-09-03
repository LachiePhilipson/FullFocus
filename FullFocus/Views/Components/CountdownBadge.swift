import SwiftUI

/// Width-stable countdown badge that avoids layout shifts by reserving space.
struct CountdownBadge: View {
    let startDate: Date
    @Environment(\.colorScheme) private var colorScheme

    private var referenceLabel: String { "Starts in 88:88" }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let interval = startDate.timeIntervalSince(context.date)
            let display = formatted(interval: interval)
            let color = EventTimingPalette.color(for: interval)

            ZStack {
                Text(referenceLabel)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .opacity(0)

                Text(display)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundColor(color)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 16)
            .background(
                Capsule().fill(color.opacity((colorScheme == .dark) ? 0.15 : 0.1))
            )
            .transaction { $0.disablesAnimations = true }
        }
    }

    private func formatted(interval: TimeInterval) -> String {
        if interval <= 0 { return "Starting now!" }
        let seconds = Int(interval)
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "Starts in %02d:%02d", minutes, secs)
    }
}

