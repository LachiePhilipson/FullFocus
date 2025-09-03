import SwiftUI

enum EventTimingPalette {
    static func color(for interval: TimeInterval) -> Color {
        if interval <= 0 { return .red }
        let minutes = Int(interval) / 60
        if minutes < 1 { return .red }
        if minutes < 5 { return .orange }
        return .green
    }
}

