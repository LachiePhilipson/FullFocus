import AppKit

final class AboutWindowElevator {
    static let shared = AboutWindowElevator()
    private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let window = note.object as? NSWindow else { return }
            // Standard About panels have titles like "About <AppName>"
            if window.title.hasPrefix("About ") {
                self.configure(window: window)
            }
        }
    }

    private func configure(window: NSWindow) {
        window.level = .floating
        window.collectionBehavior.insert(.canJoinAllSpaces)
        window.orderFrontRegardless()
    }
}
