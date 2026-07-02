import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Central place to check and request the two permissions Snaptext needs:
/// Accessibility (for the global hotkey) and Screen Recording (for screencapture).
enum Permissions {
    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    static var screenRecordingGranted: Bool { CGPreflightScreenCaptureAccess() }

    static var allGranted: Bool { accessibilityGranted && screenRecordingGranted }

    // MARK: - Individual requests

    /// Show the Accessibility permission prompt (no-op if already granted).
    static func requestAccessibility() {
        guard !accessibilityGranted else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Show the Screen Recording permission prompt and register Snaptext in the
    /// Screen Recording list.
    ///
    /// The real crop is done by the `screencapture` subprocess, which means our own
    /// process never records the screen and macOS would otherwise never list us.
    /// To make Snaptext appear in System Settings ▸ Screen & System Audio Recording,
    /// we perform one tiny *in-process* screen read here. That read is what TCC uses
    /// to register the app; it does not change the `screencapture -i` capture flow.
    static func requestScreenRecording() {
        // Ask via the official API first (shows the system prompt if needed).
        CGRequestScreenCaptureAccess()

        // Then do a minimal in-process capture so TCC registers Snaptext in the list.
        // A 1×1 read at the origin is enough to trip the screen-recording check.
        registerAsScreenRecorder()
    }

    /// Touch the screen-recording APIs from our own process, purely to register the
    /// app with TCC so it shows up (with a toggle) in the Screen Recording pane.
    /// Safe to call at launch — it does not capture the screen for real.
    static func registerAsScreenRecorder() {
        // ScreenCaptureKit's shareable-content query is the canonical trigger on
        // modern macOS: it makes the OS add the app to the Screen Recording list.
        SCShareableContent.getWithCompletionHandler { _, _ in
            // Result ignored — we only need the query to run so TCC registers us.
        }
    }

    /// Fire both system permission prompts at once (no-ops for already-granted ones).
    /// Returns `true` if everything is granted (safe to proceed).
    @discardableResult
    static func ensureAll() -> Bool {
        if allGranted { return true }
        requestScreenRecording()
        requestAccessibility()
        return allGranted
    }

    // MARK: - Open Settings panes

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open whichever panes are still needed.
    static func openSettings() {
        if !accessibilityGranted { openAccessibilitySettings() }
        if !screenRecordingGranted { openScreenRecordingSettings() }
    }
}
