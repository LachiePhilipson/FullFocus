import Foundation
import Combine
import SwiftUI
@preconcurrency import EventKit

@MainActor
final class CalendarEventMonitor: ObservableObject {
    @Published var upcomingEvents: [CalendarEvent] = []
    @Published var showBadge: Bool = false
    @Published var isRefreshing: Bool = false

    private let minRefreshIndicatorDuration: TimeInterval = 0.7
    private var refreshStartTime: Date?
    private var refreshHideWorkItem: DispatchWorkItem?
    private let store = EKEventStore()
    private var timer: AnyCancellable?
    private var lastFetchMinute: Int?
    private var alertedEventIDs: Set<String> = []
    private let snoozeStore = SnoozeStore.shared

    init() {
        requestAccess()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: store
        )
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func start() { fetchEvents(); scheduleTimer() }

    func refresh() { startRefreshing(); fetchEvents() }

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
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    if granted { self?.fetchEvents() }
                    else { print("Calendar access denied: \(error?.localizedDescription ?? "Unknown error")") }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    if granted { self?.fetchEvents() }
                    else { print("Calendar access denied: \(error?.localizedDescription ?? "Unknown error")") }
                }
            }
        }
    }

    private func scheduleTimer() {
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
        let settings = SettingsModel.shared
        let allCalendars = store.calendars(for: .event)
        let calendarsToUse: [EKCalendar]

        if settings.enabledCalendarIDs.isEmpty {
            calendarsToUse = allCalendars
        } else {
            calendarsToUse = allCalendars.filter { settings.enabledCalendarIDs.contains($0.calendarIdentifier) }
        }

        let now = Date()
        let windowEnd = Calendar.current.date(byAdding: .day, value: 7, to: now)!

        guard !calendarsToUse.isEmpty else {
            upcomingEvents = []
            endRefreshing()
            return
        }

        let predicate = store.predicateForEvents(withStart: now, end: windowEnd, calendars: calendarsToUse)
        let ignoreAllDay = settings.ignoreAllDayEvents
        let storeRef = self.store

        struct UncheckedSendable<T>: @unchecked Sendable { let value: T }
        let storeBox = UncheckedSendable(value: storeRef)
        let predicateBox = UncheckedSendable(value: predicate)
        let ignoreAllDayBox = ignoreAllDay
        let nowBox = now

        DispatchQueue.global(qos: .userInitiated).async {
            let ekEvents = storeBox.value.events(matching: predicateBox.value)
                .filter { event in
                    if ignoreAllDayBox && event.isAllDay { return false }
                    return event.endDate > nowBox
                }
                .sorted { $0.startDate < $1.startDate }

            let mapped = ekEvents.map { event in
                CalendarEvent(
                    id: event.eventIdentifier,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    url: self.extractMeetingURL(from: event),
                    isAllDay: event.isAllDay,
                    calendar: event.calendar.title.cleanedCalendarName,
                    calendarColor: Color(event.calendar.cgColor)
                )
            }

            Task { @MainActor in
                self.upcomingEvents = mapped
                let currentIDs = Set(mapped.map { $0.id })
                self.alertedEventIDs = self.alertedEventIDs.intersection(currentIDs)
                self.snoozeStore.purgeExpired()
                self.updateBadgeState()
                self.endRefreshing()
            }
        }
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

    @objc private func storeChanged() { fetchEvents() }
}

