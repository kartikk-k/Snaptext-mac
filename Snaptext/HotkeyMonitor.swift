import AppKit
import CoreGraphics

/// Watches for a global key combination and invokes a handler, **consuming** the
/// event so the frontmost app never receives it.
///
/// Uses a `CGEventTap` (not a passive `NSEvent` monitor) so the matching keystroke
/// can be swallowed system-wide. Requires Accessibility permission — the tap simply
/// won't be created (and the hotkey won't fire) until that's granted.
final class HotkeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotkey: Hotkey = .default
    private var handler: (() -> Void)?
    private var paused = false

    /// (Re)start monitoring for the given hotkey.
    func start(_ hotkey: Hotkey, handler: @escaping () -> Void) {
        self.hotkey = hotkey
        self.handler = handler
        installTap()
    }

    /// Whether the event tap is currently installed and running.
    var isActive: Bool { eventTap != nil }

    /// Re-attempt tap installation (e.g. after Accessibility is granted). No-op if
    /// already active.
    func reinstallIfNeeded() {
        guard eventTap == nil else { return }
        installTap()
    }

    /// Update the hotkey without tearing down the tap.
    func update(to hotkey: Hotkey) {
        self.hotkey = hotkey
    }

    /// Temporarily ignore the hotkey (e.g. while recording a new one).
    func pause() { paused = true }
    func resume() { paused = false }

    func stop() {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    // MARK: - CGEventTap

    private func installTap() {
        stop()

        // Only key-down events; we decide per-event whether to consume.
        let mask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap, // active tap: may modify/consume events
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            // Tap creation fails without Accessibility permission.
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
    }

    /// Returns nil to **consume** the event, or the event to pass it through.
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable if the system disabled our tap (timeout / user input).
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard !paused, type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == hotkey.keyCode else { return Unmanaged.passUnretained(event) }

        // Compare only the relevant modifier flags.
        let relevant: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let pressed = event.flags.intersection(relevant)
        guard pressed == hotkey.cgFlags else { return Unmanaged.passUnretained(event) }

        // It's our shortcut → fire the handler on the main queue and swallow the event.
        DispatchQueue.main.async { [weak self] in self?.handler?() }
        return nil
    }
}
