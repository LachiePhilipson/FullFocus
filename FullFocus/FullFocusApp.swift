import SwiftUI

@main
struct FullFocusApp: App {
    @StateObject private var eventMonitor = CalendarEventMonitor()

    init() {
        Defaults.register()
        AboutWindowElevator.shared.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(eventMonitor)
        } label: {
            Label {
                Text("FullFocus")
            } icon: {
                Image(systemName: eventMonitor.showBadge ? "bell.badge" : "bell")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsTabsView()
                .environmentObject(eventMonitor)
        }
    }
}

