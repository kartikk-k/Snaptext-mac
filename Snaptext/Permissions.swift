import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Central place to check and request the two permissions Snaptext needs:
/// Accessibility (for the global hotkey) and Screen Recording (for screencapture).
enum Permissions {
    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    static var screenRecordingGranted: Bool { CGPreflightScreenCaptureAccess() }

    static var allGranted: Bool { accessibilityGranted && screenRecordingGranted }

    // Track whether we've already asked this launch, so a second "Allow" click
    // falls back to opening System Settings (macOS only shows each dialog once).
    private static var askedAccessibility = false
    private static var askedScreenRecording = false

    // MARK: - Individual requests
    //
    // Each returns `true` if it handled the request in-app (showed the system
    // dialog), or `false` if the caller should fall back to opening the Settings
    // pane (already granted, or already asked once this launch).

    /// Show the Accessibility permission prompt. Only fires from an explicit user action.
    @discardableResult
    static func requestAccessibility() -> Bool {
        guard !accessibilityGranted else { return false }
        guard !askedAccessibility else { return false }
        askedAccessibility = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        return true
    }

    /// Show the Screen Recording permission prompt and register Snaptext in the list.
    /// Only fires from an explicit user action (clicking "Allow").
    ///
    /// The real crop is done by the `screencapture` subprocess, so our own process
    /// never records the screen and macOS would otherwise never list us. The
    /// in-process ScreenCaptureKit touch below is what registers Snaptext in
    /// System Settings ▸ Screen & System Audio Recording; it does not change the
    /// `screencapture -i` capture flow.
    @discardableResult
    static func requestScreenRecording() -> Bool {
        guard !screenRecordingGranted else { return false }
        guard !askedScreenRecording else { return false }
        askedScreenRecording = true
        // Shows the system prompt and registers us with TCC (adds us to the list).
        CGRequestScreenCaptureAccess()
        registerAsScreenRecorder()
        return true
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
}
