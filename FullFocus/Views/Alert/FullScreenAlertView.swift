import SwiftUI
import AppKit

struct FullScreenAlertView: View {
    let event: CalendarEvent
    let onClose: () -> Void
    let onSnooze: (Int) -> Void
    let onCustomSnooze: (Date) -> Void

    @ObservedObject private var settings = SettingsModel.shared
    @Environment(\.colorScheme) private var colorScheme
    private var panelMaterial: Material { .thinMaterial }
    private var overlayOpacity: CGFloat { colorScheme == .dark ? 0.10 : 0.06 }
    private var panelLiftOpacity: CGFloat { colorScheme == .dark ? 0.08 : 0.20 }

    var body: some View {
        ZStack {
            Group {
                if #available(macOS 26, *) {
                    Color.clear
                        .ignoresSafeArea()
                        .glassEffect(.regular, in: .rect(cornerRadius: 0))
                    Color.black.opacity(overlayOpacity)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onClose)
                } else {
                    Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                    Rectangle().fill(Color.black.opacity(overlayOpacity)).ignoresSafeArea().onTapGesture(perform: onClose)
                }
            }

            panel {
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
                            if #available(macOS 26, *) {
                                Button {
                                    onClose()
                                    openURLInPreferredBrowser(url)
                                } label: {
                                    Label("Join Call", systemImage: "video.fill")
                                        .font(.title3.weight(.semibold))
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 32)
                                        .background(Capsule().fill(Color.blue))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            } else {
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
                        }

                        if settings.snoozeEnabled {
                            if #available(macOS 26, *) {
                                Button { onSnooze(settings.snoozeMinutes) } label: {
                                    Label("Snooze", systemImage: "zzz")
                                        .font(.title3.weight(.semibold))
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 32)
                                        .background(Capsule().fill(Color.orange))
                                        .foregroundColor(.white)
                                }
                                .keyboardShortcut("s")
                                .buttonStyle(.plain)
                            } else {
                                Button { onSnooze(settings.snoozeMinutes) } label: {
                                    Label("Snooze", systemImage: "zzz")
                                        .font(.title3.weight(.semibold))
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 28)
                                        .background(Capsule().fill(Color.orange))
                                        .foregroundColor(.white)
                                }
                                .keyboardShortcut("s")
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .background(alignment: .center) {
                        if #available(macOS 26, *) {
                            // Draw concentric rings centered within the alert panel to align the buttons concentrically
                            ConcentricRectangle()
                                .stroke(.separator.opacity(0.25), lineWidth: 1)
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                .padding(12)
                        }
                    }
                }
                .padding(48)
                .frame(minWidth: 380)
            }
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

    @ViewBuilder
    private func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(macOS 26, *) {
            content()
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.18), radius: 24, x: 0, y: 6)
        } else {
            content()
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
        }
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

