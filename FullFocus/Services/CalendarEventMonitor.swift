import Foundation
import Combine
import SwiftUI
import OSLog
@preconcurrency import EventKit

@MainActor
final class CalendarEventMonitor: ObservableObject {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FullFocus",
        category: "CalendarEventMonitor"
    )

    @Published var upcomingEvents: [CalendarEvent] = []
    @Published var showBadge: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var calendarAccessDenied: Bool = false

    private let minRefreshIndicatorDuration: TimeInterval = 0.7
    private var refreshStartTime: Date?
    private var refreshHideWorkItem: DispatchWorkItem?
    private let store = EKEventStore()
    private var timer: AnyCancellable?
    private var hasStarted = false
    private var lastFetchMinute: Int?
    private var alertedEventIDs: Set<String> = []
    private let snoozeStore = SnoozeStore.shared

    private var storeObserver: NSObjectProtocol?

    init() {
        logger.info("CalendarEventMonitor initialized")
        requestAccess()
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.logger.info("EKEventStoreChanged received; refreshing calendars")
                self.refresh()
            }
        }
    }

    deinit {
        if let token = storeObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func start() {
        guard !hasStarted else {
            logger.info("Start requested after monitor was already started; fetching events")
            fetchEvents()
            return
        }
        hasStarted = true
        logger.info("Starting calendar monitor")
        fetchEvents()
        scheduleTimer()
    }

    func refresh() {
        logger.info("Refresh requested; accessDenied=\(self.calendarAccessDenied, privacy: .public)")
        startRefreshing()
        if calendarAccessDenied {
            logger.info("Refresh will request calendar access again")
            requestAccess()
        } else {
            fetchEvents()
        }
    }

    private func startRefreshing() {
        refreshHideWorkItem?.cancel()
        refreshStartTime = Date()
        if !isRefreshing { isRefreshing = true }
    }

    private func endRefreshing() {
        guard isRefreshing else { return }
        let elapsed = Date().timeIntervalSince(refreshStartTime ?? Date())
        let remaining = max(0, minRefreshIndicatorDuration - elapsed)
        if remaining == 0 {
            isRefreshing = false
            refreshStartTime = nil
        } else {
            let work = DispatchWorkItem { [weak self] in
                self?.isRefreshing = false
                self?.refreshStartTime = nil
            }
            refreshHideWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: work)
        }
    }

    private func requestAccess() {
        logger.info("Requesting calendar access")
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    if granted {
                        self?.logger.info("Calendar full access granted")
                        self?.calendarAccessDenied = false
                        self?.start()
                    } else {
                        self?.logger.error("Calendar full access denied: \(error?.localizedDescription ?? "Unknown error", privacy: .public)")
                        self?.calendarAccessDenied = true
                        self?.upcomingEvents = []
                        self?.endRefreshing()
                    }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    if granted {
                        self?.logger.info("Calendar access granted")
                        self?.calendarAccessDenied = false
                        self?.start()
                    } else {
                        self?.logger.error("Calendar access denied: \(error?.localizedDescription ?? "Unknown error", privacy: .public)")
                        self?.calendarAccessDenied = true
                        self?.upcomingEvents = []
                        self?.endRefreshing()
                    }
                }
            }
        }
    }

    private func scheduleTimer() {
        logger.info("Scheduling calendar refresh timer")
        timer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.evaluateAlerts()
                self.updateBadgeState()

                let currentMinute = Calendar.current.component(.minute, from: Date())
                if self.lastFetchMinute != currentMinute {
                    self.lastFetchMinute = currentMinute
                    self.fetchEvents()
                }
            }
    }

    private func fetchEvents() {
        guard !calendarAccessDenied else {
            logger.warning("Fetch skipped because calendar access is denied")
            upcomingEvents = []
            endRefreshing()
            return
        }

        let settings = SettingsModel.shared
        let allCalendars = store.calendars(for: .event)
        let calendarsToUse: [EKCalendar]
        let selectedCalendarCount = settings.hasSavedCalendarSelection ? settings.enabledCalendarIDs.count : allCalendars.count
        if !settings.hasSavedCalendarSelection {
            calendarsToUse = allCalendars
        } else if settings.enabledCalendarIDs.isEmpty {
            calendarsToUse = []
        } else {
            let selectedCalendars = allCalendars.filter { settings.enabledCalendarIDs.contains($0.calendarIdentifier) }
            calendarsToUse = selectedCalendars.isEmpty ? allCalendars : selectedCalendars
            if selectedCalendars.isEmpty {
                logger.warning("Saved calendar selection matched no current calendars; falling back to all calendars")
            }
        }

        let now = Date()
        let windowEnd = Calendar.current.date(byAdding: .day, value: 7, to: now)!

        logger.info("Fetching events; allCalendars=\(allCalendars.count, privacy: .public), selectedCalendarIDs=\(selectedCalendarCount, privacy: .public), calendarsQueried=\(calendarsToUse.count, privacy: .public), ignoreAllDay=\(settings.ignoreAllDayEvents, privacy: .public)")

        guard !calendarsToUse.isEmpty else {
            logger.warning("Fetch stopped because EventKit returned zero calendars to query")
            upcomingEvents = []
            endRefreshing()
            return
        }

        let predicate = store.predicateForEvents(withStart: now, end: windowEnd, calendars: calendarsToUse)
        let ignoreAllDay = settings.ignoreAllDayEvents
        let matchedEvents = store.events(matching: predicate)
        let ekEvents = matchedEvents
            .filter { event in
                if ignoreAllDay && event.isAllDay { return false }
                return event.endDate > now
            }
            .sorted { $0.startDate < $1.startDate }

        logger.info("Event fetch completed; matched=\(matchedEvents.count, privacy: .public), afterFilters=\(ekEvents.count, privacy: .public)")

        let mapped = ekEvents.map { event in
            CalendarEvent(
                id: self.identifier(for: event),
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                url: self.extractMeetingURL(from: event),
                isAllDay: event.isAllDay,
                calendar: event.calendar.title.cleanedCalendarName,
                calendarColor: Color(event.calendar.cgColor)
            )
        }

        upcomingEvents = mapped
        let uniqueIDCount = Set(mapped.map(\.id)).count
        logger.info("Published upcoming events; count=\(mapped.count, privacy: .public), uniqueIDs=\(uniqueIDCount, privacy: .public)")
        let currentIDs = Set(mapped.map { $0.id })
        alertedEventIDs = alertedEventIDs.intersection(currentIDs)
        snoozeStore.purgeExpired()
        updateBadgeState()
        endRefreshing()
    }

    private func identifier(for event: EKEvent) -> String {
        let sourceID = event.eventIdentifier ?? event.calendarItemIdentifier
        let occurrenceTime = Int(event.startDate.timeIntervalSinceReferenceDate)
        return "\(sourceID)-\(occurrenceTime)"
    }

    nonisolated private func extractMeetingURL(from event: EKEvent) -> URL? {
        if let url = event.url { return url }
        return MeetingURLDetector.detect(location: event.location, notes: event.notes)
    }

    private func evaluateAlerts() {
        let settings = SettingsModel.shared
        let now = Date()
        let leadTime = TimeInterval(settings.alertLeadTimeMinutes * 60)

        snoozeStore.purgeExpired(relativeTo: now)

        for event in upcomingEvents {
            if let until = snoozeStore.snoozedUntil(for: event) {
                if now >= until { showAlert(for: event, now: now) }
                continue
            }

            let timeUntilStart = event.startDate.timeIntervalSince(now)
            if timeUntilStart > 0 && timeUntilStart <= leadTime && !alertedEventIDs.contains(event.id) {
                showAlert(for: event, now: now)
            }
        }
    }

    private func showAlert(for event: CalendarEvent, now: Date = Date()) {
        FullScreenAlert.shared.show(event: event)
        alertedEventIDs.insert(event.id)
        snoozeStore.clear(for: event)
    }

    func snooze(_ event: CalendarEvent, minutes: Int) {
        let now = Date()
        let target = now.addingTimeInterval(TimeInterval(minutes * 60))
        let capped = min(target, event.startDate)
        let finalUntil = max(capped, now.addingTimeInterval(1))

        snoozeStore.setSnooze(for: event, until: finalUntil)
        alertedEventIDs.remove(event.id)
        fetchEvents()
    }

    private func updateBadgeState() {
        let settings = SettingsModel.shared
        guard settings.badgeEnabled else { showBadge = false; return }
        let now = Date()
        guard let nextEvent = upcomingEvents.first(where: { $0.startDate > now }) else {
            showBadge = false
            return
        }
        let leadTime = TimeInterval(settings.badgeLeadTimeMinutes * 60)
        let interval = nextEvent.startDate.timeIntervalSince(now)
        showBadge = interval > 0 && interval <= leadTime
    }

    @objc private func storeChanged() { refresh() }
}
