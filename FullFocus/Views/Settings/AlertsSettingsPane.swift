import SwiftUI

struct AlertsSettingsPane: View {
    @ObservedObject private var settings = SettingsModel.shared
    @EnvironmentObject var eventMonitor: CalendarEventMonitor
    private let alertSounds = [
        "Glass", "Basso", "Funk", "Hero", "Ping", "Pop", "Purr", "Sosumi",
        "Submarine", "Tink",
    ]

    var body: some View {
        Form {
            Section("Timing") {
                LabeledContent("Alerts") {
                    HStack(spacing: 8) {
                        Text("\(settings.alertLeadTimeMinutes) minute\(settings.alertLeadTimeMinutes == 1 ? "" : "s") before")
                            .monospacedDigit()
                        Stepper("", value: $settings.alertLeadTimeMinutes, in: 1...30)
                            .labelsHidden()
                    }
                }

                Toggle("Ignore all-day events", isOn: $settings.ignoreAllDayEvents)
                    .onChange(of: settings.ignoreAllDayEvents) { _, _ in
                        eventMonitor.refresh()
                    }
            }

            Section("Sound & Snooze") {
                Toggle("Play alert sound", isOn: $settings.alertSoundEnabled)

                if settings.alertSoundEnabled {
                    Picker("Alert sound", selection: $settings.alertSoundName) {
                        ForEach(alertSounds, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }

                Toggle("Snooze", isOn: $settings.snoozeEnabled)
                if settings.snoozeEnabled {
                    Picker("Snooze duration", selection: $settings.snoozeMinutes) {
                        ForEach(1...15, id: \.self) { m in
                            Text("\(m) minute\(m == 1 ? "" : "s")").tag(m)
                        }
                    }
                }
            }

            Section("Menu Bar") {
                Toggle("Show badge in menu bar", isOn: $settings.badgeEnabled)
                    .onChange(of: settings.badgeEnabled) { _, _ in
                        eventMonitor.refresh()
                    }

                if settings.badgeEnabled {
                    LabeledContent("Badge timing") {
                        HStack(spacing: 8) {
                            Text("\(settings.badgeLeadTimeMinutes) minute\(settings.badgeLeadTimeMinutes == 1 ? "" : "s") before")
                                .monospacedDigit()
                            Stepper("", value: $settings.badgeLeadTimeMinutes, in: 1...30)
                                .labelsHidden()
                                .onChange(of: settings.badgeLeadTimeMinutes) { _, _ in
                                    eventMonitor.refresh()
                                }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .fixedSize(horizontal: false, vertical: true)
    }
}

#if DEBUG
struct AlertsSettingsPane_Previews: PreviewProvider {
    static var previews: some View {
        AlertsSettingsPane()
            .environmentObject(CalendarEventMonitor())
            .frame(width: 520)
            .padding()
            .previewDisplayName("Alerts Settings")
    }
}
#endif
