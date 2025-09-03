import SwiftUI
@preconcurrency import EventKit

struct CalendarsSettingsPane: View {
    @ObservedObject private var settings = SettingsModel.shared
    @EnvironmentObject var eventMonitor: CalendarEventMonitor
    @State private var availableCalendars: [EKCalendar] = []
    @State private var storeChangeObserver: NSObjectProtocol?
    private let store = EKEventStore()

    var body: some View {
        Form {
            Section("Calendars") {
                if availableCalendars.isEmpty {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("Loading Calendars…").foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            let selectedCount = settings.enabledCalendarIDs.count
                            let totalCount = availableCalendars.count

                            Text("\(selectedCount) of \(totalCount) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button(selectedCount == totalCount ? "Deselect All" : "Select All") {
                                if selectedCount == totalCount {
                                    settings.enabledCalendarIDs = []
                                } else {
                                    settings.enabledCalendarIDs = Set(availableCalendars.map { $0.calendarIdentifier })
                                }
                                eventMonitor.refresh()
                            }
                            .buttonStyle(.link)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                                CalendarToggleRow(
                                    calendar: calendar,
                                    isEnabled: Binding(
                                        get: {
                                            settings.enabledCalendarIDs.contains(calendar.calendarIdentifier)
                                        },
                                        set: { isOn in
                                            if isOn {
                                                settings.enabledCalendarIDs.insert(calendar.calendarIdentifier)
                                            } else {
                                                settings.enabledCalendarIDs.remove(calendar.calendarIdentifier)
                                            }
                                            eventMonitor.refresh()
                                        }
                                    )
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            requestAccessIfNeeded()
            setupObservers()
        }
        .onDisappear {
            if let observer = storeChangeObserver { NotificationCenter.default.removeObserver(observer) }
        }
        .padding()
        .fixedSize(horizontal: false, vertical: true)
    }

    private func setupObservers() {
        storeChangeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { _ in
            availableCalendars = store.calendars(for: .event)
        }
    }

    private func requestAccessIfNeeded() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak store] granted, _ in
                DispatchQueue.main.async {
                    if granted { availableCalendars = store?.calendars(for: .event) ?? [] }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak store] granted, _ in
                DispatchQueue.main.async {
                    if granted { availableCalendars = store?.calendars(for: .event) ?? [] }
                }
            }
        }
    }
}

#if DEBUG
struct CalendarsSettingsPane_Previews: PreviewProvider {
    static var previews: some View {
        CalendarsSettingsPane()
            .environmentObject(CalendarEventMonitor())
            .frame(width: 520)
            .padding()
            .previewDisplayName("Calendars Settings")
    }
}
#endif
