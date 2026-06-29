import SwiftUI
import AppKit
import ServiceManagement

struct GeneralSettingsPane: View {
    @ObservedObject private var settings = SettingsModel.shared
    @EnvironmentObject var eventMonitor: CalendarEventMonitor
    @State private var launchAtLogin = false
    @State private var browsers: [BrowserApp] = []

    struct BrowserApp: Identifiable {
        let id: String
        let name: String
        let icon: NSImage
    }

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        Task { @MainActor in
                            do {
                                if newValue {
                                    if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
                                } else {
                                    if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
                                }
                            } catch {
                                print("Failed to update login item: \(error)")
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                    }
            } header: {
                Text("Startup")
            }

            Section {
                if browsers.isEmpty {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("Detecting browsers…").foregroundColor(.secondary)
                    }
                } else {
                    Picker("Open call in", selection: $settings.preferredBrowserBundleID) {
                        ForEach(browsers) { app in
                            HStack(spacing: 8) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                Text(app.name)
                            }
                            .tag(app.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text("Links")
            }

            Section {
                Text("FullFocus is made by Lachlan Philipson.")
                Button("About FullFocus") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel(nil)
                    DispatchQueue.main.async {
                        if let about = NSApp.windows.first(where: { $0.title.hasPrefix("About ") }) {
                            about.level = .floating
                            about.collectionBehavior.insert(.canJoinAllSpaces)
                            about.orderFrontRegardless()
                        }
                    }
                }
                .buttonStyle(.link)
            } header: {
                Text("Learn More")
            }
        }
        .formStyle(.grouped)
        .padding()
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            loadBrowsers()
        }
    }

    private func loadBrowsers() {
        // Use NSWorkspace URLsForApplicationsToOpenURL to avoid deprecated LS API
        let testURL = URL(string: "http://apple.com")!
        let ws = NSWorkspace.shared
        let appURLs = ws.urlsForApplications(toOpen: testURL)
        var apps: [BrowserApp] = []

        for url in appURLs {
            let bundle = Bundle(url: url)
            let id = bundle?.bundleIdentifier ?? url.lastPathComponent
            let name = (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? url.deletingPathExtension().lastPathComponent
            let icon = ws.icon(forFile: url.path)
            apps.append(BrowserApp(id: id, name: name, icon: icon))
        }

        // Deduplicate by id, sort by name
        var unique: [String: BrowserApp] = [:]
        for app in apps { unique[app.id] = app }
        let sorted = unique.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        self.browsers = sorted

        // Initialize selection to system default on first run
        if settings.preferredBrowserBundleID.isEmpty,
           let defaultURL = ws.urlForApplication(toOpen: testURL),
           let defID = Bundle(url: defaultURL)?.bundleIdentifier {
            settings.preferredBrowserBundleID = defID
        }
    }
}

#if DEBUG
struct GeneralSettingsPane_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsPane()
            .environmentObject(CalendarEventMonitor())
            .frame(width: 520)
            .padding()
            .previewDisplayName("General Settings")
    }
}
#endif
