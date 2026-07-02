import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let capture = TextCapture()
    private let hotkeyMonitor = HotkeyMonitor()
    private var recorder: ShortcutRecorderWindow?
    private var onboarding: OnboardingWindow?
    private var about: AboutWindow?

    private var hotkey = Hotkey.load()
    private var shortcutMenuItem: NSMenuItem?
    private var captureMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar utility: never show a Dock icon.
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        startHotkey()

        // Register with TCC as a screen recorder so Snaptext appears (with a toggle)
        // in System Settings ▸ Screen & System Audio Recording. Our real crop uses
        // the `screencapture` subprocess, so without this touch the OS never lists us.
        Permissions.registerAsScreenRecorder()

        // First time the app runs without all permissions, show the onboarding
        // window so the user can grant everything up front from one place.
        if !Permissions.allGranted {
            showOnboarding()
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
        // First actual use: fire both permission prompts together. If anything is
        // still missing, don't start the crop — let the user grant, then retry.
        guard Permissions.ensureAll() else {
            Permissions.openSettings()
            Toast.show("Allow Accessibility & Screen Recording, then press the shortcut again")
            return
        }
        capture.captureAndRecognize { [weak self] result in
            self?.handle(result)
        }
    }

    @objc private func recordShortcut() {
        // Pause the global hotkey so it doesn't swallow the keys being recorded.
        hotkeyMonitor.pause()
        let rec = ShortcutRecorderWindow(current: hotkey)
        recorder = rec
        rec.show(onChange: { [weak self] newHotkey in
            guard let self else { return }
            self.hotkey = newHotkey
            self.hotkeyMonitor.update(to: newHotkey)
            self.shortcutMenuItem?.title = self.shortcutTitle()
            if let item = self.captureMenuItem { self.applyKeyEquivalent(to: item) }
        }, onClosed: { [weak self] in
            self?.hotkeyMonitor.resume()
            self?.recorder = nil
        })
    }

    @objc private func showPermissions() {
        showOnboarding()
    }

    private func showOnboarding() {
        let win = OnboardingWindow()
        onboarding = win
        win.show(onClosed: { [weak self] in self?.onboarding = nil })
    }

    @objc private func showAbout() {
        let win = AboutWindow()
        about = win
        win.show()
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
