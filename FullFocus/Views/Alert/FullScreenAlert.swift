import SwiftUI
import AppKit

final class FullScreenAlert {
    static let shared = FullScreenAlert()
    private var windows: [NSWindow] = []
    private var isShowing = false
    private var keyMonitor: Any?

    func show(event: CalendarEvent) {
        show(event: event, onSnooze: { _ in }, onCustomSnooze: { _ in })
    }

    func show(
        event: CalendarEvent,
        onSnooze: @escaping (Int) -> Void,
        onCustomSnooze: @escaping (Date) -> Void
    ) {
        guard !isShowing else { return }
        let settings = SettingsModel.shared
        if settings.alertSoundEnabled,
           let sound = NSSound(named: NSSound.Name(settings.alertSoundName)) {
            sound.play()
        }
        isShowing = true

        DispatchQueue.main.async {
            self.windows.removeAll()
            for (index, screen) in NSScreen.screens.enumerated() {
                let content = FullScreenAlertView(
                    event: event,
                    onClose: { self.dismiss() },
                    onSnooze: { minutes in
                        onSnooze(minutes)
                        self.dismiss()
                    },
                    onCustomSnooze: { date in
                        onCustomSnooze(date)
                        self.dismiss()
                    }
                )

                let hosting = NSHostingView(rootView: content)
                let window = NSWindow(
                    contentRect: screen.frame,
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false,
                    screen: screen
                )
                window.setFrame(screen.frame, display: true)
                window.level = .screenSaver
                window.isOpaque = false
                window.backgroundColor = .clear
                window.contentView = hosting
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

                if index == 0 { window.makeKeyAndOrderFront(nil) }
                else { window.orderFrontRegardless() }

                self.windows.append(window)
            }

            self.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { self?.dismiss(); return nil }
                if let ch = event.charactersIgnoringModifiers?.lowercased(), ch == "s" {
                    let minutes = SettingsModel.shared.snoozeMinutes
                    onSnooze(minutes)
                    self?.dismiss()
                    return nil
                }
                return event
            }

            // Auto-dismiss after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if self.isShowing { self.dismiss() }
            }
        }
    }

    func dismiss() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        isShowing = false
    }
}
