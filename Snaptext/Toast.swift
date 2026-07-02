import AppKit

/// A borderless floating panel shown at the bottom-center of the active screen.
/// Used to confirm copied text without touching the menu bar or notifications.
enum Toast {
    private static var panel: NSPanel?
    private static var dismissWorkItem: DispatchWorkItem?

    static func show(_ message: String) {
        DispatchQueue.main.async { present(message) }
    }

    private static func present(_ message: String) {
        // Reuse a single panel; cancel any pending dismissal.
        dismissWorkItem?.cancel()

        let maxWidth: CGFloat = 520
        let text = NSTextField(labelWithString: message)
        text.font = .systemFont(ofSize: 14, weight: .medium)
        text.textColor = .white
        text.alignment = .center
        text.lineBreakMode = .byTruncatingTail
        text.maximumNumberOfLines = 2
        text.preferredMaxLayoutWidth = maxWidth - 40

        let fitting = text.sizeThatFits(NSSize(width: maxWidth - 40, height: 100))
        let contentWidth = min(maxWidth, max(160, fitting.width + 40))
        let contentHeight = max(44, fitting.height + 24)

        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor

        text.frame = NSRect(x: 20, y: (contentHeight - fitting.height) / 2,
                            width: contentWidth - 40, height: fitting.height)
        background.addSubview(text)

        let panel = existingOrNewPanel()
        panel.setContentSize(NSSize(width: contentWidth, height: contentHeight))
        panel.contentView = background

        positionAtBottomCenter(panel, size: NSSize(width: contentWidth, height: contentHeight))

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }

        let work = DispatchWorkItem { fadeOut() }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private static func existingOrNewPanel() -> NSPanel {
        if let p = panel { return p }
        let p = NSPanel(contentRect: .zero,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered,
                        defer: false)
        p.isFloatingPanel = true
        p.level = .statusBar
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.hidesOnDeactivate = false
        panel = p
        return p
    }

    private static func positionAtBottomCenter(_ panel: NSPanel, size: NSSize) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let x = visible.midX - size.width / 2
        let y = visible.minY + 80 // sit a bit above the bottom edge / Dock
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private static func fadeOut() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}
