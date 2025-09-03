import SwiftUI

struct SettingsTabsView: View {
    @EnvironmentObject var eventMonitor: CalendarEventMonitor
    var body: some View {
        TabView {
            AlertsSettingsPane()
                .environmentObject(eventMonitor)
                .tabItem { Label("Alerts", systemImage: "bell") }

            CalendarsSettingsPane()
                .environmentObject(eventMonitor)
                .tabItem { Label("Calendars", systemImage: "calendar") }

            GeneralSettingsPane()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}

