import SwiftUI

struct MenuEventRow: View {
    let event: CalendarEvent
    let isHovered: Bool
    var onTap: (() -> Void)? = nil

    var body: some View { content }

    @ViewBuilder
    private var content: some View {
        let row = rowContent
        if let onTap { Button(action: onTap) { row }.buttonStyle(.plain) }
        else { row }
    }

    private var rowContent: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor)
                .frame(width: 3)
                .padding(.vertical, 0)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                    if event.hasURL {
                        Image(systemName: "video.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Online meeting")
                    }
                    Spacer()
                }

                HStack(spacing: 4) {
                    if !event.calendar.isEmpty {
                        Text(event.calendar)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                    }

                    TimeRangeLabel(startDate: event.startDate, endDate: event.endDate)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)

                    TimeRemainingLabel(startDate: event.startDate)
                }

                if let until = SnoozeStore.shared.snoozedUntil(for: event) {
                    HStack(spacing: 4) {
                        Image(systemName: "zzz")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text("Snoozed until \(until.formatted(.dateTime.hour().minute()))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.gray.opacity(0.2) : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .fixedSize(horizontal: false, vertical: true)
    }
}

#if DEBUG
struct MenuEventRow_Previews: PreviewProvider {
    static var mockEvent = CalendarEvent(
        id: "1",
        title: "Team Standup Meeting",
        startDate: Date().addingTimeInterval(300),
        endDate: Date().addingTimeInterval(3600),
        url: URL(string: "https://zoom.us/j/123456789"),
        isAllDay: false,
        calendar: "Work",
        calendarColor: .blue
    )

    static var previews: some View {
        VStack(spacing: 0) {
            MenuEventRow(event: mockEvent, isHovered: false)
            Divider()
            MenuEventRow(event: mockEvent, isHovered: true)
        }
        .frame(width: 320)
        .padding(.vertical)
        .previewDisplayName("Menu Event Row")
    }
}
#endif
