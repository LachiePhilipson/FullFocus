import SwiftUI
import AppKit
@preconcurrency import EventKit

struct CalendarsSettingsPane: View {
    @ObservedObject private var settings = SettingsModel.shared
    @EnvironmentObject var eventMonitor: CalendarEventMonitor
    @State private var availableCalendars: [EKCalendar] = []
    @State private var storeChangeObserver: NSObjectProtocol?
    @State private var accessDenied: Bool = false
    private let store = EKEventStore()

    var body: some View {
        Form {
            Section("Calendars") {
                if accessDenied {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Calendar access is required", systemImage: "calendar.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                        Button("Open System Settings…") { openCalendarPrivacySettings() }
                            .buttonStyle(.link)
                        Text("Grant permission to access your calendars, then return to the app.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if availableCalendars.isEmpty {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("Loading Calendars…").foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            let selectedCount = selectedCalendarCount
                            let totalCount = availableCalendars.count

                            Text("\(selectedCount) of \(totalCount) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button(selectedCount == totalCount ? "Deselect All" : "Select All") {
                                setAllCalendarsSelected(selectedCount != totalCount)
                            }
                            .buttonStyle(.link)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                                CalendarToggleRow(
                                    calendar: calendar,
                                    isEnabled: Binding(
                                        get: {
                                            isCalendarEnabled(calendar)
                                        },
                                        set: { isOn in
                                            setCalendar(calendar, isEnabled: isOn)
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

    private var selectedCalendarCount: Int {
        guard settings.hasSavedCalendarSelection else {
            return availableCalendars.count
        }

        let availableIDs = Set(availableCalendars.map { $0.calendarIdentifier })
        return settings.enabledCalendarIDs.intersection(availableIDs).count
    }

    private func isCalendarEnabled(_ calendar: EKCalendar) -> Bool {
        !settings.hasSavedCalendarSelection || settings.enabledCalendarIDs.contains(calendar.calendarIdentifier)
    }

    private func setAllCalendarsSelected(_ isSelected: Bool) {
        settings.enabledCalendarIDs = isSelected ? Set(availableCalendars.map { $0.calendarIdentifier }) : []
        eventMonitor.refresh()
    }

    private func setCalendar(_ calendar: EKCalendar, isEnabled: Bool) {
        var enabledIDs = settings.hasSavedCalendarSelection
            ? settings.enabledCalendarIDs
            : Set(availableCalendars.map { $0.calendarIdentifier })

        if isEnabled {
            enabledIDs.insert(calendar.calendarIdentifier)
        } else {
            enabledIDs.remove(calendar.calendarIdentifier)
        }

        settings.enabledCalendarIDs = enabledIDs
        eventMonitor.refresh()
    }

    private func requestAccessIfNeeded() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, _ in
                Task { @MainActor in
                    self.accessDenied = !granted
                    if granted {
                        availableCalendars = self.store.calendars(for: .event)
                    } else {
                        availableCalendars = []
                    }
                }
            }
        } else {
            store.requestAccess(to: .event) { granted, _ in
                Task { @MainActor in
                    self.accessDenied = !granted
                    if granted {
                        availableCalendars = self.store.calendars(for: .event)
                    } else {
                        availableCalendars = []
                    }
                }
            }
        }
    }
    
    private func openCalendarPrivacySettings() {
        let ws = NSWorkspace.shared
        if let url = URL(string: "x-apple.systempreferences:com.apple.Settings.extension/Privacy_Calendars") {
            ws.open(url)
            return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference/security?Privacy") {
            ws.open(url)
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
