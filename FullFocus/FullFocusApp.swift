//
//  FullFocusApp.swift
//  FullFocus
//
//  Created by Lachlan Philipson on 7/31/25.
//

import SwiftUI
import EventKit
import Combine
import AppKit
import ServiceManagement

final class SettingsModel: ObservableObject {
    static let shared = SettingsModel()
    @AppStorage("alertLeadTimeMinutes") var alertLeadTimeMinutes: Int = 1
    @AppStorage("enabledCalendarIDs") var enabledCalendarIDsData: Data = Data()
    
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


@main
struct FullFocusApp: App {
    @StateObject private var eventMonitor = CalendarEventMonitor()
    @Environment(\.openSettings) private var openSettings
    
    var body: some Scene {
        MenuBarExtra("FullFocus", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        if let next = eventMonitor.nextEvent {
                            Text("Upcoming")
                                .font(.subheadline)
                            Text(next.title)
                                .font(.headline)
                                .bold()
                                .lineLimit(2)
                            Text("Starts: \(next.startDate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.footnote)
                        } else {
                            Text("No upcoming events")
                                .font(.body)
                        }
                    }
                    Divider()
                    Button(action: {
                        NSApp.activate(ignoringOtherApps: true)
                        openSettings()
                    }) {
                        Text("Settings...")
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
                
                Divider()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
            .frame(width: 260)
            .task {
                eventMonitor.start()
            }
        }
        Settings {
            SettingsView()
                .environmentObject(eventMonitor)
        }
    }
    
    
}

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let url: URL?
}

final class CalendarEventMonitor: ObservableObject {
    @Published var nextEvent: CalendarEvent?
    private let store = EKEventStore()
    private var timer: AnyCancellable?
    private var authorizationCheckCancellable: AnyCancellable?
    private var lastAlertEventID: String?
    
    init() {
        requestAccess()
        NotificationCenter.default.addObserver(self, selector: #selector(storeChanged), name: .EKEventStoreChanged, object: store)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .EKEventStoreChanged, object: store)
    }
    
    func start() {
        scheduleTimer()
    }
    
    func refresh() {
        fetchNextEvent()
    }
    
    private func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    if granted {
                        self.fetchNextEvent()
                        self.scheduleTimer()
                    } else {
                        print("Calendar access denied")
                    }
                }
            }
        } else {
            store.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    if granted {
                        self.fetchNextEvent()
                        self.scheduleTimer()
                    } else {
                        print("Calendar access denied")
                    }
                }
            }
        }
    }
    
    private func scheduleTimer() {
        timer = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchNextEvent()
                self?.evaluateAlertCondition()
            }
    }
    
    private func fetchNextEvent() {
        let allCalendars = store.calendars(for: .event)
        let calendarsToUse: [EKCalendar]
        let enabled = SettingsModel.shared.enabledCalendarIDs
        if enabled.isEmpty {
            calendarsToUse = []
        } else {
            calendarsToUse = allCalendars.filter { enabled.contains($0.calendarIdentifier) }
        }
        let now = Date()
        let windowEnd = Calendar.current.date(byAdding: .hour, value: 8, to: now)!
        let predicate = store.predicateForEvents(withStart: now, end: windowEnd, calendars: calendarsToUse)
        let ekEvents = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        if let first = ekEvents.first {
            let ce = CalendarEvent(
                id: first.eventIdentifier,
                title: first.title,
                startDate: first.startDate,
                endDate: first.endDate,
                url: firstMeetingURL(in: first)
            )
            if nextEvent?.id != ce.id {
                nextEvent = ce
                lastAlertEventID = nil   // reset alert state for new event
            }
        } else {
            nextEvent = nil
            lastAlertEventID = nil   // clear any previous alert when no events
        }
    }
    
    private func firstMeetingURL(in event: EKEvent) -> URL? {
        if let url = event.url { return url }
        
        let sources = [event.location ?? "", event.notes ?? ""]
        let pattern = #"https?://[^\s]+"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        
        for text in sources {
            guard let match = regex?.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range, in: text) else { continue }
            return URL(string: String(text[range]))
        }
        return nil
    }
    
    private func evaluateAlertCondition() {
        guard let event = nextEvent else { return }
        if lastAlertEventID == event.id { return }   // avoid duplicate alerts for the same event
        let now = Date()
        let timeInterval = event.startDate.timeIntervalSince(now)
        let lead = TimeInterval(SettingsModel.shared.alertLeadTimeMinutes * 60)
        if timeInterval > 0 && timeInterval <= lead {
            FullScreenAlert.shared.show(event: event)
            lastAlertEventID = event.id   // remember that we've fired for this event
        }
    }
    
    @objc private func storeChanged() {
        fetchNextEvent()
        evaluateAlertCondition()
    }
}

class FullScreenAlert {
    static let shared = FullScreenAlert()
    private var windows: [NSWindow] = []
    private var isShowing = false
    
    func show(event: CalendarEvent) {
        guard !isShowing else { return }
        isShowing = true
        DispatchQueue.main.async {
            self.windows.removeAll()
            for screen in NSScreen.screens {
                let content = FullScreenAlertView(event: event) {
                    self.dismiss()
                }
                let hosting = NSHostingView(rootView: content)
                let win = NSWindow(
                    contentRect: screen.frame,
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false,
                    screen: screen
                )
                win.setFrame(screen.frame, display: true)
                win.level = .screenSaver
                win.isOpaque = false
                win.backgroundColor = .clear
                win.contentView = hosting
                win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                win.orderFrontRegardless()
                self.windows.append(win)
            }
        }
    }
    
    func dismiss() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        isShowing = false
    }
}

struct FullScreenAlertView: View {
    let event: CalendarEvent
    let onClose: () -> Void
    
    private var minutesUntilStart: Int {
        max(Int(event.startDate.timeIntervalSince(Date()) / 60), 0)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                Image(systemName: "bell.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
                    .font(.system(size: 72))
                    .padding(.bottom, 18)
                
                Text("Upcoming Meeting")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                
                Text(event.title)
                    .font(.system(.largeTitle).bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Text("Starts in \(minutesUntilStart) minute\(minutesUntilStart == 1 ? "" : "s") at \(event.startDate.formatted(.dateTime.hour().minute()))")
                    .font(.title3)
                
                if let meetingURL = event.url {
                    Link(destination: meetingURL) {
                        Label("Join Call", systemImage: "video.fill")
                            .font(.title3.weight(.medium))
                            .padding(.vertical, 12)
                            .padding(.horizontal, 18)
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundColor(.white)
                            .labelStyle(.titleAndIcon)
                    }
                    .padding(.top, 24)
                }
                
            }
            .padding(40)
            .background(
                .ultraThickMaterial,
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .shadow(radius: 12)
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
                .padding(12)
            }
        }
        .transition(.opacity)
    }
}

#if DEBUG
#Preview {
    FullScreenAlertView(
        event: CalendarEvent(
            id: UUID().uuidString,
            title: "Design Review",
            startDate: Date().addingTimeInterval(300),          // 5 min from now
            endDate: Date().addingTimeInterval(3_600),          // 1 hr later
            url: URL(string: "https://meet.example.com")
        ),
        onClose: {}
    )
}
#endif

struct SettingsView: View {
    @ObservedObject private var settings = SettingsModel.shared
    @EnvironmentObject var eventMonitor: CalendarEventMonitor
    @State private var availableCalendars: [EKCalendar] = []
    @State private var storeChangeObserver: NSObjectProtocol?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    private let store = EKEventStore()
    
    var body: some View {
        Form {
            Section("Alert Preferences") {
                Stepper(
                    value: Binding(
                        get: { settings.alertLeadTimeMinutes },
                        set: { settings.alertLeadTimeMinutes = $0 }
                    ),
                    in: 1...30
                ) {
                    Text("\(settings.alertLeadTimeMinutes) minute(s) before")
                }
                
                Button("Test Alert") {
                    let eventToShow: CalendarEvent
                    if let next = eventMonitor.nextEvent {
                        eventToShow = next
                    } else {
                        eventToShow = CalendarEvent(
                            id: UUID().uuidString,
                            title: "Test Event",
                            startDate: Date().addingTimeInterval(60),   // 1 min from now
                            endDate: Date().addingTimeInterval(3600),   // 1 hr later
                            url: nil
                        )
                    }
                    FullScreenAlert.shared.show(event: eventToShow)
                }
                
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                if SMAppService.mainApp.status != .enabled {
                                    try SMAppService.mainApp.register()
                                }
                            } else {
                                if SMAppService.mainApp.status == .enabled {
                                    try SMAppService.mainApp.unregister()
                                }
                            }
                        } catch {
                            print("Failed to update login item: \(error)")
                        }
                    }
            }
            
            Section("Calendars") {
                if availableCalendars.isEmpty {
                    Text("Loading calendars…")
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        
                        HStack {
                            let allSelected = settings.enabledCalendarIDs.count == availableCalendars.count && !availableCalendars.isEmpty
                            Button(allSelected ? "Deselect All" : "Select All") {
                                if allSelected {
                                    settings.enabledCalendarIDs = []
                                } else {
                                    settings.enabledCalendarIDs = Set(availableCalendars.map { $0.calendarIdentifier })
                                }
                            }
                            
                            Button("Refresh Events") {
                                eventMonitor.refresh()
                            }
                        }
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(availableCalendars, id: \.calendarIdentifier) { cal in
                                    Toggle(cal.title, isOn: Binding(
                                        get: { settings.enabledCalendarIDs.contains(cal.calendarIdentifier) },
                                        set: { isOn in
                                            if isOn {
                                                settings.enabledCalendarIDs.insert(cal.calendarIdentifier)
                                            } else {
                                                settings.enabledCalendarIDs.remove(cal.calendarIdentifier)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.checkbox)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(maxHeight: 220)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: nil)
        .onAppear {
            requestAccessIfNeeded()
            storeChangeObserver = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
                availableCalendars = store.calendars(for: .event)
            }
        }
        .onDisappear {
            if let observer = storeChangeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    private func requestAccessIfNeeded() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        availableCalendars = store.calendars(for: .event)
                    }
                }
            }
        } else {
            store.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        availableCalendars = store.calendars(for: .event)
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("FullFocus is running in the menu bar.")
            .padding()
    }
}
