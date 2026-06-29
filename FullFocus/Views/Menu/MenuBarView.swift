import SwiftUI
import AppKit
import OSLog

enum EventFilter: String, CaseIterable {
    case next = "Next"
    case today = "Today"
    case week = "Week"
}

struct MenuBarView: View {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FullFocus",
        category: "MenuBar"
    )

    @EnvironmentObject private var eventMonitor: CalendarEventMonitor
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss
    @State private var eventFilter: EventFilter = .today
    @State private var hoveredEventID: String?

    var filteredEvents: [CalendarEvent] {
        switch eventFilter {
        case .next:
            return Array(eventMonitor.upcomingEvents.prefix(1))
        case .today:
            let calendar = Calendar.current
            let endOfDay = calendar.dateInterval(of: .day, for: Date())?.end ?? Date()
            return eventMonitor.upcomingEvents.filter { $0.startDate < endOfDay }
        case .week:
            let calendar = Calendar.current
            if let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.end {
                return eventMonitor.upcomingEvents.filter { $0.startDate < endOfWeek }
            } else {
                return eventMonitor.upcomingEvents
            }
        }
    }

    private var groupedWeekEvents: [(date: Date, events: [CalendarEvent])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredEvents) { calendar.startOfDay(for: $0.startDate) }
        return groups.keys.sorted().map { date in
            (date, (groups[date] ?? []).sorted { $0.startDate < $1.startDate })
        }
    }

    private static let dayHeaderFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE – MMM d"
        return df
    }()

    private enum Layout {
        static let rowEstimate: CGFloat = 58
        static let wrappedRowEstimate: CGFloat = 78
        static let headerEstimate: CGFloat = 38
        static let dividerEstimate: CGFloat = 17
        static let verticalInsets: CGFloat = 8
        static let maxScrollableHeight: CGFloat = 620
    }

    private var calculatedEventsHeight: CGFloat {
        switch eventFilter {
        case .next:
            return eventListHeight(for: filteredEvents.prefix(1)) + Layout.verticalInsets
        case .today:
            return eventListHeight(for: filteredEvents) + Layout.verticalInsets
        case .week:
            guard !groupedWeekEvents.isEmpty else {
                return Layout.rowEstimate + Layout.verticalInsets
            }

            return groupedWeekEvents.reduce(CGFloat(0)) { total, group in
                total
                    + Layout.headerEstimate
                    + eventListHeight(for: group.events)
                    + (group.date == groupedWeekEvents.last?.date ? 0 : Layout.dividerEstimate)
            } + Layout.verticalInsets
        }
    }

    private func eventListHeight<S: Sequence>(for events: S) -> CGFloat where S.Element == CalendarEvent {
        let eventArray = Array(events)
        guard !eventArray.isEmpty else {
            return Layout.rowEstimate
        }

        return eventArray.enumerated().reduce(CGFloat(0)) { total, pair in
            let (_, event) = pair
            return total + estimatedRowHeight(for: event)
        } + CGFloat(max(eventArray.count - 1, 0)) * Layout.dividerEstimate
    }

    private func estimatedRowHeight(for event: CalendarEvent) -> CGFloat {
        if event.title.count > 36 {
            return Layout.wrappedRowEstimate
        } else {
            return Layout.rowEstimate
        }
    }

    private var eventsSectionHeight: CGFloat? {
        switch eventFilter {
        case .next:
            return nil
        case .today:
            return min(calculatedEventsHeight, Layout.maxScrollableHeight)
        case .week:
            return min(calculatedEventsHeight, Layout.maxScrollableHeight)
        }
    }

    private var usesScrollView: Bool {
        guard let height = eventsSectionHeight else {
            return false
        }

        return calculatedEventsHeight > height
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider().padding(.horizontal, 12)
            eventsScrollSection
            Divider().padding(.horizontal, 12)
            footerSection
        }
        .frame(width: 320)
        .onAppear { logVisibleEventState(reason: "menu appeared") }
        .onChange(of: eventFilter) { _, _ in logVisibleEventState(reason: "filter changed") }
        .onChange(of: eventMonitor.upcomingEvents.count) { _, _ in logVisibleEventState(reason: "upcoming count changed") }
    }

    // Sections
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("FullFocus")
                .font(.headline)
                .padding(.horizontal, 4)

            Spacer(minLength: 8)

            Picker(selection: $eventFilter) {
                ForEach(EventFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            } label: { EmptyView() }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .padding(8)
    }

    @ViewBuilder private var eventsScrollSection: some View {
        if let height = eventsSectionHeight {
            sizedEventsSection
                .frame(height: height, alignment: .top)
        } else {
            eventListContent
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var sizedEventsSection: some View {
        if usesScrollView {
            ScrollView { eventListContent }
        } else {
            eventListContent
        }
    }

    @ViewBuilder private var eventListContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if eventMonitor.calendarAccessDenied {
                statusMessage(
                    "Calendar access is required",
                    systemImage: "calendar.badge.exclamationmark"
                )
            } else if filteredEvents.isEmpty {
                statusMessage(emptyEventsMessage, systemImage: "calendar")
            } else {
                switch eventFilter {
                case .week:
                    weekList
                default:
                    dayList
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var emptyEventsMessage: String {
        switch eventFilter {
        case .next:
            return "No upcoming events"
        case .today:
            return "No events today"
        case .week:
            return "No events this week"
        }
    }

    @ViewBuilder private var weekList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(groupedWeekEvents, id: \.date) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(Self.dayHeaderFormatter.string(from: group.date))
                        .font(.headline.weight(.semibold))
                        .padding(.horizontal, 4)
                        .padding(4)
                    ForEach(group.events) { event in
                        MenuEventRow(
                            event: event,
                            isHovered: hoveredEventID == event.id,
                            onTap: {
                                FullScreenAlert.shared.show(
                                    event: event,
                                    onSnooze: { minutes in eventMonitor.snooze(event, minutes: minutes) },
                                    onCustomSnooze: { date in
                                        let mins = max(1, Int(date.timeIntervalSinceNow / 60))
                                        eventMonitor.snooze(event, minutes: mins)
                                    }
                                )
                            }
                        )
                        .onHover { hovering in hoveredEventID = hovering ? event.id : nil }
                    }
                    if group.date != groupedWeekEvents.last?.date {
                        Divider().padding(.horizontal, 12).padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(4)
    }

    @ViewBuilder private var dayList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(filteredEvents) { event in
                MenuEventRow(
                    event: event,
                    isHovered: hoveredEventID == event.id,
                    onTap: {
                        FullScreenAlert.shared.show(
                            event: event,
                            onSnooze: { minutes in eventMonitor.snooze(event, minutes: minutes) },
                            onCustomSnooze: { date in
                                let mins = max(1, Int(date.timeIntervalSinceNow / 60))
                                eventMonitor.snooze(event, minutes: mins)
                            }
                        )
                    }
                )
                .onHover { hovering in hoveredEventID = hovering ? event.id : nil }

                if event.id != filteredEvents.last?.id {
                    Divider().padding(.horizontal, 12)
                }
            }
        }
        .padding(4)
    }

    private func statusMessage(_ message: String, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .font(.body)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.rowEstimate)
            .padding(4)
            .accessibilityElement(children: .combine)
    }

    private func logVisibleEventState(reason: String) {
        logger.info("Menu render state: \(reason, privacy: .public); filter=\(eventFilter.rawValue, privacy: .public), upcoming=\(eventMonitor.upcomingEvents.count, privacy: .public), filtered=\(filteredEvents.count, privacy: .public), accessDenied=\(eventMonitor.calendarAccessDenied, privacy: .public)")
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button("Settings…") {
                // Close the menu bar dropdown/window first
                dismiss()
                // Then bring the app to the foreground and open Settings
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
            }
            .buttonStyle(ControlCenterButtonStyle())

            Button(action: {
                logger.info("Refresh Calendars selected from menu bar")
                eventMonitor.refresh()
            }) {
                HStack {
                    Text("Refresh Calendars")
                    Spacer()
                    if eventMonitor.isRefreshing {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .buttonStyle(ControlCenterButtonStyle())

            Divider().padding(.horizontal, 8).padding(.vertical, 4)

            Button("Quit FullFocus") { NSApp.terminate(nil) }
                .buttonStyle(ControlCenterButtonStyle())
        }
        .padding(4)
    }
}

#if DEBUG
struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView()
            .environmentObject(CalendarEventMonitor())
            .frame(width: 320)
            .previewDisplayName("Menu Bar")
    }
}
#endif
