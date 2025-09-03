import Foundation
import SwiftUI

// Calendar event value used by the UI and services.
struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let url: URL?
    let isAllDay: Bool
    let calendar: String
    let calendarColor: Color

    var hasURL: Bool { url != nil }

    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
}

