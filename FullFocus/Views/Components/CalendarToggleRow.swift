import SwiftUI
@preconcurrency import EventKit

struct CalendarToggleRow: View {
    let calendar: EKCalendar
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(calendar.cgColor))
                    .frame(width: 10, height: 10)

                Text(calendar.title.cleanedCalendarName)
                    .font(.system(size: 13))
            }
        }
        .toggleStyle(.checkbox)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}

