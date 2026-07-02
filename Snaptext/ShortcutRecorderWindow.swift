import AppKit

/// A tiny panel that captures the next key-combo the user presses and reports it back.
final class ShortcutRecorderWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var monitor: Any?
    private var onChange: ((Hotkey) -> Void)?
    private let label = NSTextField(labelWithString: "")
    private var current: Hotkey

    init(current: Hotkey) {
        self.current = current
    }

    func show(onChange: @escaping (Hotkey) -> Void) {
        self.onChange = onChange

        if window != nil {
            bringToFront()
            return
        }

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 150))

        let title = NSTextField(labelWithString: "Record Shortcut")
        title.font = .boldSystemFont(ofSize: 15)
        title.frame = NSRect(x: 20, y: 110, width: 300, height: 22)
        content.addSubview(title)

        let instructions = NSTextField(labelWithString: "Press the key combination you want to use.")
        instructions.textColor = .secondaryLabelColor
        instructions.font = .systemFont(ofSize: 12)
        instructions.frame = NSRect(x: 20, y: 86, width: 300, height: 18)
        content.addSubview(instructions)

        label.stringValue = current.displayString
        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 22, weight: .medium)
        label.frame = NSRect(x: 20, y: 40, width: 300, height: 34)
        label.wantsLayer = true
        label.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        label.layer?.cornerRadius = 8
        content.addSubview(label)

        let hint = NSTextField(labelWithString: "Esc cancels · needs at least one ⌘/⌥/⌃/⇧")
        hint.textColor = .tertiaryLabelColor
        hint.font = .systemFont(ofSize: 10)
        hint.alignment = .center
        hint.frame = NSRect(x: 20, y: 14, width: 300, height: 16)
        content.addSubview(hint)

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

        NSApp.setActivationPolicy(.regular) // temporarily so the panel can take focus
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)

        startCapturing()
    }

    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func startCapturing() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }

            if event.type == .keyDown {
                if event.keyCode == 53 { // Esc
                    self.close()
                    return nil
                }
                let mask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
                let mods = event.modifierFlags.intersection(mask)
                guard !mods.isEmpty else {
                    NSSound.beep() // require a modifier
                    return nil
                }
                let hk = Hotkey(keyCode: event.keyCode, modifiers: mods.rawValue)
                self.current = hk
                self.label.stringValue = hk.displayString
                hk.save()
                self.onChange?(hk)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.close() }
                return nil
            }
            return nil // swallow flagsChanged while recording
        }
    }

    private func stopCapturing() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    func close() {
        stopCapturing()
        window?.close()
        window = nil
        NSApp.setActivationPolicy(.accessory) // back to menu-bar-only
    }

    func windowWillClose(_ notification: Notification) {
        stopCapturing()
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
