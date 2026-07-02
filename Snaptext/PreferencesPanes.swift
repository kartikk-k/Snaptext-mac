import AppKit

// MARK: - Permissions Pane

/// Lists the two required permissions with live status + Allow buttons.
final class PermissionsPane: NSView {
    private var accessibilityRow: PermissionRow!
    private var screenRow: PermissionRow!
    private var footer: NSTextField!
    private var timer: Timer?

    init() {
        super.init(frame: .zero)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let title = makeLabel("Permissions", font: .systemFont(ofSize: 18, weight: .bold))
        let subtitle = makeLabel("Snaptext needs these to capture and read text from your screen.",
                                 font: .systemFont(ofSize: 12), color: .secondaryLabelColor, lines: 2)

        accessibilityRow = PermissionRow(
            symbol: "accessibility",
            title: "Accessibility",
            subtitle: "Enables the global shortcut",
            action: #selector(grantAccessibility), target: self)

        screenRow = PermissionRow(
            symbol: "rectangle.dashed.badge.record",
            title: "Screen Recording",
            subtitle: "Lets Snaptext capture the selected area",
            action: #selector(grantScreen), target: self)

        footer = makeLabel("", font: .systemFont(ofSize: 12, weight: .semibold),
                           color: .secondaryLabelColor, lines: 2)

        for v in [title, subtitle, accessibilityRow, screenRow, footer] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }

        let pad: CGFloat = 24
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: pad),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),

            accessibilityRow.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 20),
            accessibilityRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            accessibilityRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            accessibilityRow.heightAnchor.constraint(equalToConstant: 64),

            screenRow.topAnchor.constraint(equalTo: accessibilityRow.bottomAnchor, constant: 12),
            screenRow.leadingAnchor.constraint(equalTo: accessibilityRow.leadingAnchor),
            screenRow.trailingAnchor.constraint(equalTo: accessibilityRow.trailingAnchor),
            screenRow.heightAnchor.constraint(equalToConstant: 64),

            footer.topAnchor.constraint(equalTo: screenRow.bottomAnchor, constant: 18),
            footer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            footer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
        ])
    }

    func startPolling() {
        stopPolling()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    func stopPolling() { timer?.invalidate(); timer = nil }

    func refresh() {
        accessibilityRow.setGranted(Permissions.accessibilityGranted)
        screenRow.setGranted(Permissions.screenRecordingGranted)
        let allSet = Permissions.allGranted
        footer.stringValue = allSet
            ? "All set! Press your shortcut anywhere to capture text."
            : "Click Allow on each permission to get started."
        footer.textColor = allSet ? .systemGreen : .secondaryLabelColor
    }

    @objc private func grantAccessibility() {
        if !Permissions.requestAccessibility() { Permissions.openAccessibilitySettings() }
    }
    @objc private func grantScreen() {
        if !Permissions.requestScreenRecording() { Permissions.openScreenRecordingSettings() }
    }
}

// MARK: - Shortcut Pane

/// Records a new global shortcut using a first-responder key-capture view.
final class ShortcutPane: NSView {
    var onChange: ((Hotkey) -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?

    private let captureView = KeyCaptureView()
    private let comboLabel = NSTextField(labelWithString: "")
    private var current = Hotkey.load()
    private var recording = false

    init() {
        super.init(frame: .zero)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let title = makeLabel("Shortcut", font: .systemFont(ofSize: 18, weight: .bold))
        let subtitle = makeLabel("Press a key combination to set your capture shortcut.",
                                 font: .systemFont(ofSize: 12), color: .secondaryLabelColor, lines: 2)

        comboLabel.stringValue = current.displayString
        comboLabel.alignment = .center
        comboLabel.font = .monospacedSystemFont(ofSize: 26, weight: .semibold)
        comboLabel.wantsLayer = true
        comboLabel.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        comboLabel.layer?.cornerRadius = 12
        comboLabel.layer?.borderWidth = 1
        comboLabel.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
        comboLabel.isBezeled = false
        comboLabel.drawsBackground = false

        let hint = makeLabel("Needs at least one modifier (⌘ ⌥ ⌃ ⇧). Esc cancels.",
                             font: .systemFont(ofSize: 11), color: .tertiaryLabelColor)
        hint.alignment = .center

        captureView.onCombo = { [weak self] keyCode, mods in
            guard let self else { return }
            let hk = Hotkey(keyCode: keyCode, modifiers: mods.rawValue)
            self.current = hk
            self.comboLabel.stringValue = hk.displayString
            hk.save()
            self.onChange?(hk)
        }
        captureView.onCancel = { [weak self] in
            self?.comboLabel.stringValue = self?.current.displayString ?? ""
        }

        for v in [title, subtitle, comboLabel, hint, captureView] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        // The capture view is invisible but must be in the hierarchy to receive keys.
        captureView.widthAnchor.constraint(equalToConstant: 1).isActive = true
        captureView.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let pad: CGFloat = 24
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: pad),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),

            comboLabel.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 24),
            comboLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            comboLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            comboLabel.heightAnchor.constraint(equalToConstant: 60),

            hint.topAnchor.constraint(equalTo: comboLabel.bottomAnchor, constant: 14),
            hint.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    /// Make the capture view first responder so keys are recorded.
    func focusForRecording() {
        guard let win = window else { return }
        win.makeFirstResponder(captureView)
        if !recording { recording = true; onRecordingChanged?(true) }
    }

    func endRecording() {
        if recording { recording = false; onRecordingChanged?(false) }
    }
}

// MARK: - About Pane

final class AboutPane: NSView {
    init() {
        super.init(frame: .zero)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let iconContainer = NSView()
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
        iconContainer.layer?.cornerRadius = 16

        let icon = NSImageView()
        let cfg = NSImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
        icon.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Snaptext")?
            .withSymbolConfiguration(cfg)
        icon.contentTintColor = .controlAccentColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(icon)

        let name = makeLabel("Snaptext", font: .systemFont(ofSize: 22, weight: .bold))
        name.alignment = .center
        let version = makeLabel("Version \(Self.versionString)",
                                font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        version.alignment = .center
        let desc = makeLabel("Capture any text on screen with your shortcut.\nExtracted instantly with Apple’s on-device OCR.",
                             font: .systemFont(ofSize: 12), color: .secondaryLabelColor, lines: 2)
        desc.alignment = .center
        let note = makeLabel("Uses the built-in macOS screen capture & Vision.",
                             font: .systemFont(ofSize: 10), color: .tertiaryLabelColor)
        note.alignment = .center

        for v in [iconContainer, name, version, desc, note] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }

        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: topAnchor, constant: 32),
            iconContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 72),
            iconContainer.heightAnchor.constraint(equalToConstant: 72),
            icon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            name.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 16),
            name.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            name.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            version.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 4),
            version.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            version.trailingAnchor.constraint(equalTo: name.trailingAnchor),

            desc.topAnchor.constraint(equalTo: version.bottomAnchor, constant: 16),
            desc.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            desc.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            note.topAnchor.constraint(equalTo: desc.bottomAnchor, constant: 16),
            note.leadingAnchor.constraint(equalTo: desc.leadingAnchor),
            note.trailingAnchor.constraint(equalTo: desc.trailingAnchor),
        ])
    }

    private static var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

// MARK: - Shared helper

/// Convenience label factory used across the panes.
func makeLabel(_ text: String, font: NSFont,
               color: NSColor = .labelColor, lines: Int = 1) -> NSTextField {
    let l = NSTextField(labelWithString: text)
    l.font = font
    l.textColor = color
    l.maximumNumberOfLines = lines
    l.lineBreakMode = lines > 1 ? .byWordWrapping : .byTruncatingTail
    l.cell?.wraps = lines > 1
    return l
}

// MARK: - KeyCaptureView

/// A view that becomes first responder and captures the next key combination.
final class KeyCaptureView: NSView {
    var onCombo: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    /// Intercept key equivalents (e.g. ⌘-combos) that would otherwise be swallowed.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handle(event); return true
    }
    override func keyDown(with event: NSEvent) { handle(event) }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 { onCancel?(); return } // Esc
        let mask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let mods = event.modifierFlags.intersection(mask)
        guard !mods.isEmpty else { NSSound.beep(); return }
        onCombo?(event.keyCode, mods)
    }
}

// MARK: - PillView

/// A rounded status pill with a perfectly centered label.
final class PillView: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(equalTo: label.widthAnchor, constant: 18),
            heightAnchor.constraint(equalToConstant: 18),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func set(text: String, color: NSColor) {
        label.stringValue = text
        label.textColor = color
        layer?.backgroundColor = color.withAlphaComponent(0.15).cgColor
    }
}

// MARK: - PermissionRow

/// A single card row: symbol · title/subtitle · status pill · Allow button.
final class PermissionRow: NSView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let statusPill = PillView()
    private let button = NSButton()

    init(symbol: String, title: String, subtitle: String, action: Selector, target: AnyObject) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor

        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)?
            .withSymbolConfiguration(config)
        iconView.contentTintColor = .labelColor

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        subtitleLabel.stringValue = subtitle
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor

        button.title = "Allow"
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.target = target
        button.action = action

        for v in [iconView, titleLabel, subtitleLabel, statusPill, button] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 13),

            statusPill.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            statusPill.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -12),

            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 88),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func setGranted(_ granted: Bool) {
        statusPill.set(text: granted ? "Granted" : "Needed",
                       color: granted ? .systemGreen : .systemOrange)
        button.isHidden = granted
        alphaValue = granted ? 0.7 : 1.0
    }
}
