import Foundation
import EventKit

actor EventStoreActor {
    private let store = EKEventStore()

    // Request calendar access in an async-friendly way
    func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(macOS 14.0, *) {
                store.requestFullAccessToEvents { granted, _ in
                    continuation.resume(returning: granted)
                }
            } else {
                store.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // Retrieve calendars for events
    func calendars() -> [EKCalendar] {
        store.calendars(for: .event)
    }

    // Create an EKEventStore predicate
    func predicate(start: Date, end: Date, calendars: [EKCalendar]) -> NSPredicate {
        store.predicateForEvents(withStart: start, end: end, calendars: calendars)
    }

    // Fetch events matching a predicate
    func events(matching predicate: NSPredicate) -> [EKEvent] {
        store.events(matching: predicate)
    }
}
