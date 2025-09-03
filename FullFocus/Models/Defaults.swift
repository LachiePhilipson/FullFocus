import Foundation

// App defaults and registration
enum Defaults {
    static let alertLeadTimeMinutes: Int = 4
    static let ignoreAllDayEvents: Bool = true
    static let alertSoundName: String = "Glass"
    static let alertSoundEnabled: Bool = true
    static let badgeEnabled: Bool = true
    static let badgeLeadTimeMinutes: Int = 5
    static let snoozeEnabled: Bool = false
    static let snoozeMinutes: Int = 2

    static func register() {
        UserDefaults.standard.register(defaults: [
            "alertLeadTimeMinutes": alertLeadTimeMinutes,
            "enabledCalendarIDs": Data(),
            "ignoreAllDayEvents": ignoreAllDayEvents,
            "alertSoundName": alertSoundName,
            "alertSoundEnabled": alertSoundEnabled,
            "badgeEnabled": badgeEnabled,
            "badgeLeadTimeMinutes": badgeLeadTimeMinutes,
            "snoozeEnabled": snoozeEnabled,
            "snoozeMinutes": snoozeMinutes,
            "preferredBrowserBundleID": "",
        ])
    }
}

