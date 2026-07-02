import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let capture = TextCapture()
    private let hotkeyMonitor = HotkeyMonitor()
    private var recorder: ShortcutRecorderWindow?

    private var hotkey = Hotkey.load()
    private var shortcutMenuItem: NSMenuItem?
    private var captureMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar utility: never show a Dock icon.
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        startHotkey()

        // Ask for Accessibility on first launch so the global shortcut works
        // even when Snaptext isn't the focused app.
        if !HotkeyMonitor.isTrusted {
            HotkeyMonitor.promptForTrust()
        }
    }

    private func startHotkey() {
        hotkeyMonitor.start(hotkey) { [weak self] in
            self?.captureText()
        }
    }

    // MARK: - Menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.viewfinder",
                                   accessibilityDescription: "Snaptext")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let captureItem = NSMenuItem(title: "Capture Text",
                                     action: #selector(captureText),
                                     keyEquivalent: "")
        captureItem.target = self
        applyKeyEquivalent(to: captureItem)
        menu.addItem(captureItem)
        captureMenuItem = captureItem

        menu.addItem(.separator())

        let shortcutItem = NSMenuItem(title: shortcutTitle(),
                                      action: #selector(recordShortcut),
                                      keyEquivalent: "")
        shortcutItem.target = self
        menu.addItem(shortcutItem)
        shortcutMenuItem = shortcutItem

        let accessibilityItem = NSMenuItem(title: "Accessibility Permission…",
                                           action: #selector(openAccessibility),
                                           keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Snaptext",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func shortcutTitle() -> String {
        "Change Shortcut (\(hotkey.displayString))…"
    }

    /// Mirror the hotkey onto the Capture menu item's key equivalent for discoverability.
    private func applyKeyEquivalent(to item: NSMenuItem) {
        let key = Hotkey.keyName(for: hotkey.keyCode).lowercased()
        // Only single printable characters work as menu key equivalents.
        item.keyEquivalent = key.count == 1 ? key : ""
        item.keyEquivalentModifierMask = hotkey.flags
    }

    // MARK: - Actions

    @objc private func captureText() {
        capture.captureAndRecognize { [weak self] result in
            self?.handle(result)
        }
    }

    @objc private func recordShortcut() {
        let rec = ShortcutRecorderWindow(current: hotkey)
        recorder = rec
        rec.show { [weak self] newHotkey in
            guard let self else { return }
            self.hotkey = newHotkey
            self.hotkeyMonitor.update(to: newHotkey)
            self.shortcutMenuItem?.title = self.shortcutTitle()
            if let item = self.captureMenuItem { self.applyKeyEquivalent(to: item) }
        }
    }

    @objc private func openAccessibility() {
        if HotkeyMonitor.isTrusted {
            Toast.show("Accessibility is already granted — the shortcut is active")
        } else {
            HotkeyMonitor.promptForTrust()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Result handling

    private func handle(_ result: TextCapture.Result) {
        switch result {
        case .cancelled:
            break // user pressed Esc during selection — stay quiet
        case .empty:
            Toast.show("No text found")
        case .text(let string):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
            let preview = string.count > 80 ? String(string.prefix(80)) + "…" : string
            Toast.show(preview)
        case .failure(let message):
            Toast.show(message)
        }
    }
}
