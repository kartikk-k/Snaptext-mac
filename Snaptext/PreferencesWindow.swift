import AppKit

/// A single unified window with three tabs — Permissions, Shortcut, About —
/// replacing the previous separate Onboarding / Recorder / About windows.
final class PreferencesWindow: NSObject, NSWindowDelegate, NSToolbarDelegate {
    enum Tab: String, CaseIterable {
        case permissions, shortcut, about
        var title: String {
            switch self {
            case .permissions: return "Permissions"
            case .shortcut:    return "Shortcut"
            case .about:       return "About"
            }
        }
        var symbol: String {
            switch self {
            case .permissions: return "lock.shield"
            case .shortcut:    return "keyboard"
            case .about:       return "info.circle"
            }
        }
    }

    static let shared = PreferencesWindow()

    private var window: NSWindow?
    private var container: NSView!
    private var current: Tab = .permissions

    private let permissionsView = PermissionsPane()
    private let shortcutView = ShortcutPane()
    private let aboutView = AboutPane()

    /// Called when the user records a new hotkey; wired up by AppDelegate.
    var onHotkeyChange: ((Hotkey) -> Void)?
    /// Called while the shortcut tab is active so the global hotkey can be paused.
    var onShortcutRecordingChanged: ((Bool) -> Void)?

    // MARK: - Presentation

    func show(_ tab: Tab = .permissions) {
        if window == nil { build() }
        select(tab)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        // Ensure key focus lands after activation completes (needed for recording).
        DispatchQueue.main.async { [weak self] in
            guard let self, let win = self.window else { return }
            win.makeKeyAndOrderFront(nil)
            if self.current == .shortcut { self.shortcutView.focusForRecording() }
        }
    }

    private func build() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 380))

        // Material background.
        let effect = NSVisualEffectView(frame: content.bounds)
        effect.material = .underWindowBackground
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]
        content.addSubview(effect)

        container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            container.topAnchor.constraint(equalTo: effect.topAnchor),
            container.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])

        let win = NSWindow(contentRect: content.frame,
                           styleMask: [.titled, .closable, .unifiedTitleAndToolbar],
                           backing: .buffered,
                           defer: false)
        win.title = "Snaptext"
        win.toolbarStyle = .preference
        win.contentView = content
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.center()

        let toolbar = NSToolbar(identifier: "SnaptextPrefsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier = NSToolbarItem.Identifier(Tab.permissions.rawValue)
        win.toolbar = toolbar

        self.window = win

        shortcutView.onChange = { [weak self] hk in self?.onHotkeyChange?(hk) }
        shortcutView.onRecordingChanged = { [weak self] active in
            self?.onShortcutRecordingChanged?(active)
        }
    }

    private func select(_ tab: Tab) {
        current = tab
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(tab.rawValue)

        container.subviews.forEach { $0.removeFromSuperview() }
        let pane: NSView
        switch tab {
        case .permissions:
            permissionsView.refresh()
            permissionsView.startPolling()
            pane = permissionsView
        case .shortcut:
            pane = shortcutView
        case .about:
            pane = aboutView
        }
        if tab != .permissions { permissionsView.stopPolling() }
        if tab != .shortcut { shortcutView.endRecording() }

        pane.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(pane)
        NSLayoutConstraint.activate([
            pane.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pane.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pane.topAnchor.constraint(equalTo: container.topAnchor),
            pane.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        if tab == .shortcut {
            DispatchQueue.main.async { [weak self] in self?.shortcutView.focusForRecording() }
        }
    }

    @objc private func toolbarItemSelected(_ sender: NSToolbarItem) {
        if let tab = Tab(rawValue: sender.itemIdentifier.rawValue) { select(tab) }
    }

    // MARK: - NSToolbarDelegate

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = Tab(rawValue: id.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = tab.title
        item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
        item.target = self
        item.action = #selector(toolbarItemSelected(_:))
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Tab.allCases.map { NSToolbarItem.Identifier($0.rawValue) }
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        permissionsView.stopPolling()
        shortcutView.endRecording()
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
