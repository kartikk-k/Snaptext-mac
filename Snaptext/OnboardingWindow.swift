import AppKit

/// A small window shown on first launch (or from the menu) when permissions are
/// missing. Offers a button per required permission; each row shows a live
/// granted/needed status and disables once granted.
final class OnboardingWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onClosed: (() -> Void)?
    private var refreshTimer: Timer?

    private var accessibilityButton: NSButton!
    private var screenButton: NSButton!
    private var accessibilityStatus: NSTextField!
    private var screenStatus: NSTextField!
    private var doneLabel: NSTextField!

    func show(onClosed: @escaping () -> Void) {
        self.onClosed = onClosed
        if let win = window { bringToFront(win); return }

        let width: CGFloat = 400, height: CGFloat = 250
        let content = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        let title = NSTextField(labelWithString: "Welcome to Snaptext")
        title.font = .boldSystemFont(ofSize: 17)
        title.frame = NSRect(x: 24, y: height - 48, width: width - 48, height: 24)
        content.addSubview(title)

        let subtitle = NSTextField(labelWithString: "Snaptext needs two permissions to capture and read text from your screen.")
        subtitle.textColor = .secondaryLabelColor
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.frame = NSRect(x: 24, y: height - 82, width: width - 48, height: 32)
        subtitle.maximumNumberOfLines = 2
        subtitle.lineBreakMode = .byWordWrapping
        content.addSubview(subtitle)

        // Accessibility row
        let axLabel = NSTextField(labelWithString: "Accessibility — global ⌘⇧2 shortcut")
        axLabel.font = .systemFont(ofSize: 13)
        axLabel.frame = NSRect(x: 24, y: 150, width: 250, height: 18)
        content.addSubview(axLabel)

        accessibilityStatus = statusLabel(frame: NSRect(x: 24, y: 132, width: 200, height: 14))
        content.addSubview(accessibilityStatus)

        accessibilityButton = NSButton(title: "Allow", target: self, action: #selector(grantAccessibility))
        accessibilityButton.bezelStyle = .rounded
        accessibilityButton.frame = NSRect(x: width - 120, y: 140, width: 96, height: 28)
        content.addSubview(accessibilityButton)

        // Screen Recording row
        let scLabel = NSTextField(labelWithString: "Screen Recording — capture the crop")
        scLabel.font = .systemFont(ofSize: 13)
        scLabel.frame = NSRect(x: 24, y: 98, width: 250, height: 18)
        content.addSubview(scLabel)

        screenStatus = statusLabel(frame: NSRect(x: 24, y: 80, width: 200, height: 14))
        content.addSubview(screenStatus)

        screenButton = NSButton(title: "Allow", target: self, action: #selector(grantScreen))
        screenButton.bezelStyle = .rounded
        screenButton.frame = NSRect(x: width - 120, y: 88, width: 96, height: 28)
        content.addSubview(screenButton)

        doneLabel = NSTextField(labelWithString: "")
        doneLabel.font = .systemFont(ofSize: 12, weight: .medium)
        doneLabel.textColor = .systemGreen
        doneLabel.frame = NSRect(x: 24, y: 24, width: width - 48, height: 32)
        doneLabel.maximumNumberOfLines = 2
        content.addSubview(doneLabel)

        let win = NSWindow(contentRect: content.frame,
                           styleMask: [.titled, .closable],
                           backing: .buffered,
                           defer: false)
        win.title = "Snaptext"
        win.contentView = content
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.center()
        self.window = win

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)

        refresh()
        // Poll so the UI updates as the user flips toggles in System Settings.
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func statusLabel(frame: NSRect) -> NSTextField {
        let l = NSTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 11)
        l.frame = frame
        return l
    }

    private func bringToFront(_ win: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    private func refresh() {
        let ax = Permissions.accessibilityGranted
        let sc = Permissions.screenRecordingGranted

        accessibilityStatus.stringValue = ax ? "Granted" : "Not granted"
        accessibilityStatus.textColor = ax ? .systemGreen : .systemOrange
        accessibilityButton.title = ax ? "Granted ✓" : "Allow"
        accessibilityButton.isEnabled = !ax

        screenStatus.stringValue = sc ? "Granted" : "Not granted"
        screenStatus.textColor = sc ? .systemGreen : .systemOrange
        screenButton.title = sc ? "Granted ✓" : "Allow"
        screenButton.isEnabled = !sc

        doneLabel.stringValue = (ax && sc)
            ? "All set! Press ⌘⇧2 anywhere to capture text. You can close this window."
            : ""
    }

    @objc private func grantAccessibility() {
        Permissions.requestAccessibility()
        Permissions.openAccessibilitySettings()
    }

    @objc private func grantScreen() {
        Permissions.requestScreenRecording()
        Permissions.openScreenRecordingSettings()
    }

    func windowWillClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
        window = nil
        NSApp.setActivationPolicy(.accessory)
        onClosed?()
    }
}
