import AppKit

/// A small About window reachable from the menu bar.
final class AboutWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        if let win = window { bringToFront(win); return }

        let width: CGFloat = 340, height: CGFloat = 220
        let content = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        let icon = NSImageView(frame: NSRect(x: (width - 64) / 2, y: height - 92, width: 64, height: 64))
        icon.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Snaptext")
        icon.contentTintColor = .labelColor
        icon.imageScaling = .scaleProportionallyUpOrDown
        content.addSubview(icon)

        let name = NSTextField(labelWithString: "Snaptext")
        name.font = .boldSystemFont(ofSize: 20)
        name.alignment = .center
        name.frame = NSRect(x: 0, y: height - 122, width: width, height: 26)
        content.addSubview(name)

        let version = NSTextField(labelWithString: "Version \(Self.versionString)")
        version.font = .systemFont(ofSize: 12)
        version.textColor = .secondaryLabelColor
        version.alignment = .center
        version.frame = NSRect(x: 0, y: height - 144, width: width, height: 16)
        content.addSubview(version)

        let desc = NSTextField(labelWithString: "Capture any text on screen with ⌘⇧2.\nExtracted instantly with Apple’s on-device OCR.")
        desc.font = .systemFont(ofSize: 12)
        desc.textColor = .secondaryLabelColor
        desc.alignment = .center
        desc.maximumNumberOfLines = 2
        desc.lineBreakMode = .byWordWrapping
        desc.frame = NSRect(x: 20, y: 44, width: width - 40, height: 36)
        content.addSubview(desc)

        let copyright = NSTextField(labelWithString: "Uses the built-in macOS screen capture & Vision.")
        copyright.font = .systemFont(ofSize: 10)
        copyright.textColor = .tertiaryLabelColor
        copyright.alignment = .center
        copyright.frame = NSRect(x: 20, y: 18, width: width - 40, height: 14)
        content.addSubview(copyright)

        let win = NSWindow(contentRect: content.frame,
                           styleMask: [.titled, .closable],
                           backing: .buffered,
                           defer: false)
        win.title = "About Snaptext"
        win.contentView = content
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.center()
        self.window = win

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    private func bringToFront(_ win: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    private static var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
