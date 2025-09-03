import Foundation
import SwiftUI

final class SettingsModel: ObservableObject {
    static let shared = SettingsModel()

    @AppStorage("alertLeadTimeMinutes") var alertLeadTimeMinutes: Int = Defaults.alertLeadTimeMinutes
    @AppStorage("enabledCalendarIDs") var enabledCalendarIDsData: Data = Data()
    @AppStorage("ignoreAllDayEvents") var ignoreAllDayEvents: Bool = Defaults.ignoreAllDayEvents
    /// Selected alert sound name; use "None" to disable.
    @AppStorage("alertSoundName") var alertSoundName: String = Defaults.alertSoundName
    /// Whether an alert sound should play.
    @AppStorage("alertSoundEnabled") var alertSoundEnabled: Bool = Defaults.alertSoundEnabled

    /// Whether the menu bar icon should display a badge.
    @AppStorage("badgeEnabled") var badgeEnabled: Bool = Defaults.badgeEnabled
    /// Minutes before an event starts when the badge should appear.
    @AppStorage("badgeLeadTimeMinutes") var badgeLeadTimeMinutes: Int = Defaults.badgeLeadTimeMinutes

    @AppStorage("snoozeEnabled") var snoozeEnabled: Bool = Defaults.snoozeEnabled
    @AppStorage("snoozeMinutes") var snoozeMinutes: Int = Defaults.snoozeMinutes

    /// Preferred browser bundle identifier for opening meeting links.
    /// Empty string means not set yet; UI will initialize to system default.
    @AppStorage("preferredBrowserBundleID") var preferredBrowserBundleID: String = ""

    @Published var enabledCalendarIDs: Set<String> = [] {
        didSet {
            if let data = try? JSONEncoder().encode(enabledCalendarIDs) {
                enabledCalendarIDsData = data
            }
        }
    }

    init() {
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: enabledCalendarIDsData) {
            enabledCalendarIDs = decoded
        }
    }
}

