import Foundation
import SwiftUI

final class SnoozeStore: ObservableObject {
    static let shared = SnoozeStore()

    @AppStorage("snoozesData") private var snoozesData: Data = Data()
    @Published private(set) var snoozes: [String: Date] = [:]  // key -> snoozedUntil

    private init() {
        if let dict = try? JSONDecoder().decode([String: Date].self, from: snoozesData) {
            snoozes = dict
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snoozes) {
            snoozesData = data
        }
    }

    /// Unique key per event occurrence (id + start time)
    func key(for event: CalendarEvent) -> String {
        let t = Int(event.startDate.timeIntervalSinceReferenceDate)
        return "\(event.id)_\(t)"
    }

    func snoozedUntil(for event: CalendarEvent) -> Date? {
        snoozes[key(for: event)]
    }

    func setSnooze(for event: CalendarEvent, until: Date) {
        snoozes[key(for: event)] = until
        persist()
    }

    func clear(for event: CalendarEvent) {
        snoozes.removeValue(forKey: key(for: event))
        persist()
    }

    /// Remove any past snoozes
    func purgeExpired(relativeTo now: Date = Date()) {
        snoozes = snoozes.filter { $0.value > now }
        persist()
    }
}

