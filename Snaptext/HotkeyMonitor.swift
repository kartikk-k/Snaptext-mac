import AppKit

/// Watches for a global key combination and invokes a handler.
///
/// Uses `NSEvent` global + local monitors. The global monitor fires system-wide
/// even when Snaptext is not the focused app, provided Accessibility permission
/// is granted. The local monitor covers the case where one of our own windows is key.
final class HotkeyMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hotkey: Hotkey = .default
    private var handler: (() -> Void)?

    /// (Re)start monitoring for the given hotkey.
    func start(_ hotkey: Hotkey, handler: @escaping () -> Void) {
        self.hotkey = hotkey
        self.handler = handler
        stop()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handle(event) == true { return nil } // swallow when it's our hotkey
            return event
        }
    }

    /// Update the hotkey without tearing down the monitors.
    func update(to hotkey: Hotkey) {
        self.hotkey = hotkey
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    @discardableResult
    private func handle(_ event: NSEvent) -> Bool {
        guard hotkey.matches(event) else { return false }
        handler?()
        return true
    }

    // MARK: - Accessibility permission

    /// Whether the process is trusted for Accessibility (needed for the global monitor).
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant Accessibility permission (opens System Settings).
    static func promptForTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
