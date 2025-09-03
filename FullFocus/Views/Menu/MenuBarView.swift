import SwiftUI
import AppKit

enum EventFilter: String, CaseIterable {
    case next = "Next"
    case today = "Today"
    case week = "Week"
}

struct MenuBarView: View {
    @EnvironmentObject private var eventMonitor: CalendarEventMonitor
    @Environment(\.openSettings) private var openSettings
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
        static let rowEstimate: CGFloat = 66
        static let headerEstimate: CGFloat = 36
        static let verticalInsets: CGFloat = 12
    }

    private var baseScrollHeight: CGFloat {
        switch eventFilter {
        case .next:
            return Layout.rowEstimate * 2 + Layout.verticalInsets
        case .today:
            let rows = min(5, filteredEvents.count)
            let base = CGFloat(max(rows, 1)) * Layout.rowEstimate
            return base + Layout.verticalInsets
        case .week:
            let maxDays = 3
            let maxRowsPerDay = 3
            let totalHeaders = Layout.headerEstimate * CGFloat(maxDays)
            let totalRows = Layout.rowEstimate * CGFloat(maxDays * maxRowsPerDay)
            return totalHeaders + totalRows + Layout.verticalInsets
        }
    }

    private var maxScrollHeight: CGFloat { baseScrollHeight * 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider().padding(.horizontal, 12)
            eventsScrollSection
            Divider().padding(.horizontal, 12)
            footerSection
        }
        .frame(width: 320)
        .task { eventMonitor.start() }
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

    private var eventsScrollSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                switch eventFilter {
                case .week:
                    weekList
                default:
                    dayList
                }
            }
        }
        .frame(maxHeight: maxScrollHeight)
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
            if filteredEvents.isEmpty {
                Text("No upcoming events")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.rowEstimate)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.clear)
                    )
            } else {
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
        }
        .padding(4)
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button("Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            .buttonStyle(ControlCenterButtonStyle())

            Button(action: { eventMonitor.refresh() }) {
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
