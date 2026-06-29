import SwiftUI
import AppKit

/// A helper view that configures its hosting window to open on top and remain frontmost when shown.
struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Defer to next runloop to ensure the view is in a window
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            configure(window: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Re-apply configuration in case the window changes
        DispatchQueue.main.async { [weak nsView] in
            guard let window = nsView?.window else { return }
            configure(window: window)
        }
    }

    private func configure(window: NSWindow) {
        // Ensure the Settings window is frontmost and easy to find
        window.level = .floating
        window.collectionBehavior.insert(.canJoinAllSpaces)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
