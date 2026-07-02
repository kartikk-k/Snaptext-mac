import AppKit

/// A view that becomes first responder and captures the next key combination.
private final class KeyCaptureView: NSView {
    var onCombo: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    /// Intercept key equivalents (e.g. ⌘-combos) that would otherwise be swallowed
    /// by the menu / window before keyDown is delivered.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handle(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        handle(event)
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onCancel?()
            return
        }
        let mask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let mods = event.modifierFlags.intersection(mask)
        guard !mods.isEmpty else {
            NSSound.beep() // require at least one modifier
            return
        }
        onCombo?(event.keyCode, mods)
    }
}

/// A tiny window that captures the next key-combo the user presses and reports it back.
final class ShortcutRecorderWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onChange: ((Hotkey) -> Void)?
    private var onClosed: (() -> Void)?
    private let label = NSTextField(labelWithString: "")
    private var current: Hotkey
    private let captureView = KeyCaptureView(frame: NSRect(x: 0, y: 0, width: 340, height: 150))

    init(current: Hotkey) {
        self.current = current
    }

    /// - onChange: called with each new hotkey.
    /// - onClosed: called when the window closes (used to resume the global hotkey).
    func show(onChange: @escaping (Hotkey) -> Void, onClosed: @escaping () -> Void) {
        self.onChange = onChange
        self.onClosed = onClosed

        if let win = window {
            bringToFront(win)
            return
        }

        let content = captureView

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

        captureView.onCombo = { [weak self] keyCode, mods in
            guard let self else { return }
            let hk = Hotkey(keyCode: keyCode, modifiers: mods.rawValue)
            self.current = hk
            self.label.stringValue = hk.displayString
            hk.save()
            self.onChange?(hk)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.close() }
        }
        captureView.onCancel = { [weak self] in self?.close() }

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

        // Become a regular app briefly so the window can take keyboard focus.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(captureView)
    }

    private func bringToFront(_ win: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(captureView)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApp.setActivationPolicy(.accessory) // back to menu-bar-only
        onClosed?()
    }
}
