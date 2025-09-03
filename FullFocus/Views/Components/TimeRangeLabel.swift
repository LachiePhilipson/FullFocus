import SwiftUI

/// Formats a compact time range such as “12 – 1:30 PM”.
struct TimeRangeLabel: View {
    let startDate: Date
    let endDate: Date

    private static let meridiemFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "a"
        df.locale = .autoupdatingCurrent
        return df
    }()

    private static let fullFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }()

    var body: some View {
        let parts = buildParts()
        (Text(parts.leading) + Text(parts.meridiem).font(.system(size: 11).smallCaps()))
            .monospacedDigit()
            .accessibilityLabel(parts.accessibility)
            .transaction { $0.disablesAnimations = true }
    }

    private func buildParts() -> (leading: String, meridiem: String, accessibility: String) {
        let cal = Calendar.current
        let startComps = cal.dateComponents([.hour, .minute], from: startDate)
        let endComps = cal.dateComponents([.hour, .minute], from: endDate)

        let startMeridiem = Self.meridiemFormatter.string(from: startDate)
        let endMeridiem = Self.meridiemFormatter.string(from: endDate)

        func hourMinute(_ comps: DateComponents, includeMinutesWhenZero: Bool) -> String {
            guard let hour24 = comps.hour, let minute = comps.minute else { return "" }
            var hour12 = hour24 % 12
            if hour12 == 0 { hour12 = 12 }
            if minute == 0 && !includeMinutesWhenZero { return "\(hour12)" }
            else { return String(format: "\(hour12):%02d", minute) }
        }

        let sameMeridiem = (startMeridiem == endMeridiem)
        let startStr = hourMinute(startComps, includeMinutesWhenZero: false)
        let endStr = hourMinute(endComps, includeMinutesWhenZero: false)

        let leading: String
        let meridiem: String

        if sameMeridiem {
            leading = "\(startStr) – \(endStr)"
            meridiem = endMeridiem
        } else {
            leading = "\(startStr)\(startMeridiem) – \(endStr)\(endMeridiem)"
            meridiem = ""
        }

        let accessibility = "\(Self.fullFormatter.string(from: startDate)) to \(Self.fullFormatter.string(from: endDate))"
        return (leading, meridiem, accessibility)
    }
}

