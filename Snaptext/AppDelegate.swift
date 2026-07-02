import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let capture = TextCapture()
    private let hotkeyMonitor = HotkeyMonitor()
    private let prefs = PreferencesWindow.shared

    private var hotkey = Hotkey.load()
    private var shortcutMenuItem: NSMenuItem?
    private var captureMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar utility: never show a Dock icon.
        NSApp.setActivationPolicy(.accessory)

        // Always use dark mode regardless of the system theme.
        NSApp.appearance = NSAppearance(named: .darkAqua)

        setupStatusItem()
        startHotkey()
        wirePreferences()

        // Show the unified window on the Permissions tab whenever a permission is
        // still missing — on first launch AND on every restart until everything is
        // granted. No system dialogs fire here; those only appear when the user
        // clicks "Allow".
        if !Permissions.allGranted {
            prefs.show(.permissions)
        }
    }

    private func wirePreferences() {
        prefs.onHotkeyChange = { [weak self] newHotkey in
            guard let self else { return }
            self.hotkey = newHotkey
            self.hotkeyMonitor.update(to: newHotkey)
            self.shortcutMenuItem?.title = self.shortcutTitle()
            if let item = self.captureMenuItem { self.applyKeyEquivalent(to: item) }
        }
        // Pause the global hotkey while the Shortcut tab is capturing keys.
        prefs.onShortcutRecordingChanged = { [weak self] recording in
            if recording { self?.hotkeyMonitor.pause() } else { self?.hotkeyMonitor.resume() }
        }
    }

    private func startHotkey() {
        hotkeyMonitor.start(hotkey) { [weak self] in
            self?.captureText()
        }
        // The CGEventTap can only be created once Accessibility is granted. If it
        // isn't yet, keep retrying so the shortcut comes online without a restart.
        if !hotkeyMonitor.isActive {
            let t = Timer(timeInterval: 1.5, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                self.hotkeyMonitor.reinstallIfNeeded()
                if self.hotkeyMonitor.isActive { timer.invalidate() }
            }
            RunLoop.main.add(t, forMode: .common)
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
                                      action: #selector(showShortcut),
                                      keyEquivalent: "")
        shortcutItem.target = self
        menu.addItem(shortcutItem)
        shortcutMenuItem = shortcutItem

        let permissionsItem = NSMenuItem(title: "Permissions…",
                                         action: #selector(showPermissions),
                                         keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        let aboutItem = NSMenuItem(title: "About Snaptext",
                                   action: #selector(showAbout),
                                   keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

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
        // If a permission is missing, route the user to the Permissions tab rather
        // than firing system dialogs unprompted.
        guard Permissions.allGranted else {
            prefs.show(.permissions)
            return
        }
        capture.captureAndRecognize { [weak self] result in
            self?.handle(result)
        }
    }

    @objc private func showShortcut()   { prefs.show(.shortcut) }
    @objc private func showPermissions() { prefs.show(.permissions) }
    @objc private func showAbout()       { prefs.show(.about) }

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
