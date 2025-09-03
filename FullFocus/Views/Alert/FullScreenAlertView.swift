import SwiftUI
import AppKit

struct FullScreenAlertView: View {
    let event: CalendarEvent
    let onClose: () -> Void
    let onSnooze: (Int) -> Void
    let onCustomSnooze: (Date) -> Void

    @ObservedObject private var settings = SettingsModel.shared
    @Environment(\.colorScheme) private var colorScheme
    private var panelMaterial: Material { .thickMaterial }
    private var overlayOpacity: CGFloat { colorScheme == .dark ? 0.20 : 0.12 }
    private var panelLiftOpacity: CGFloat { colorScheme == .dark ? 0.12 : 0.35 }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Rectangle().fill(Color.black.opacity(overlayOpacity)).ignoresSafeArea().onTapGesture(perform: onClose)

            VStack(spacing: 24) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let interval = event.startDate.timeIntervalSince(context.date)
                    Image(systemName: "bell.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, EventTimingPalette.color(for: interval))
                        .font(.system(size: 72))
                        .symbolEffect(.wiggle, options: .repeat(.continuous))
                        .transaction { $0.disablesAnimations = true }
                }

                VStack(spacing: 16) {
                    Text("Upcoming event")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(.secondary)

                    Text(event.title)
                        .font(.system(size: 36, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Label(event.calendar, systemImage: "calendar").font(.title3)
                        Text("•")
                        Text(event.startDate.formatted(.dateTime.hour().minute())).font(.title3)
                    }

                    CountdownBadge(startDate: event.startDate)
                }

                HStack(spacing: 14) {
                    if let url = event.url {
                        Button {
                            onClose()
                            openURLInPreferredBrowser(url)
                        } label: {
                            Label("Join Call", systemImage: "video.fill")
                                .font(.title3.weight(.semibold))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 28)
                                .background(Capsule().fill(Color.blue))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    if settings.snoozeEnabled {
                        Button { onSnooze(settings.snoozeMinutes) } label: {
                            Label("Snooze", systemImage: "zzz")
                                .font(.title3.weight(.semibold))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 28)
                                .background(Capsule().fill(Color.gray.opacity(0.3)))
                                .foregroundColor(.white)
                        }
                        .keyboardShortcut("s")
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(48)
            .frame(minWidth: 380)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous).fill(panelMaterial)
                    RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.white.opacity(panelLiftOpacity))
                }
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.2), radius: 30, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.12), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.separator.opacity(colorScheme == .dark ? 0.35 : 0.5), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close")
                .accessibilityIdentifier("closeAlert")
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.plain)
                .padding(16)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func openURLInPreferredBrowser(_ url: URL) {
        let preferredID = SettingsModel.shared.preferredBrowserBundleID
        guard !preferredID.isEmpty,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: preferredID) else {
            NSWorkspace.shared.open(url)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config) { _, _ in }
    }
}

#if DEBUG
struct FullScreenAlertView_Previews: PreviewProvider {
    static var mockEvent = CalendarEvent(
        id: "1",
        title: "Meeting",
        startDate: Date().addingTimeInterval(120),
        endDate: Date().addingTimeInterval(3600),
        url: URL(string: "https://zoom.us/j/123456789"),
        isAllDay: false,
        calendar: "Work",
        calendarColor: .blue
    )

    static var previews: some View {
        FullScreenAlertView(
            event: mockEvent,
            onClose: {},
            onSnooze: { _ in },
            onCustomSnooze: { _ in }
        )
        .frame(width: 800, height: 600)
        .background(Color.gray)
        .previewDisplayName("Full Screen Alert")
    }
}
#endif
