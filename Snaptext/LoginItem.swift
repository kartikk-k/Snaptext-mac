import ServiceManagement

/// Manages the "Launch at Login" state using the modern SMAppService API
/// (macOS 13+). Registers the main app itself as a login item — no helper needed.
enum LoginItem {
    /// Whether Snaptext is currently set to open at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Turn launch-at-login on or off. Returns the resulting state.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Snaptext: failed to update login item: \(error.localizedDescription)")
        }
        return isEnabled
    }

    /// Enable launch-at-login by default on first run (only once, so the user can
    /// later turn it off and have that choice respected).
    static func enableByDefaultIfNeeded() {
        let key = "snaptext.didSetDefaultLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        setEnabled(true)
    }
}
