import AppKit
import Carbon.HIToolbox

/// A key combination that can be persisted and displayed.
struct Hotkey: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt   // raw value of NSEvent.ModifierFlags (device-independent subset)

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    static let `default` = Hotkey(
        keyCode: 19, // "2"
        modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue
    )

    /// Human-readable form, e.g. "⌘⇧2".
    var displayString: String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option)  { s += "⌥" }
        if flags.contains(.shift)   { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        s += Hotkey.keyName(for: keyCode)
        return s
    }

    /// Matches an incoming event against this hotkey (ignoring irrelevant flags like caps lock).
    func matches(_ event: NSEvent) -> Bool {
        guard event.keyCode == keyCode else { return false }
        let mask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        return event.modifierFlags.intersection(mask) == flags.intersection(mask)
    }

    // MARK: Persistence

    private static let defaultsKey = "snaptext.hotkey"

    static func load() -> Hotkey {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let hk = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return .default
        }
        return hk
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Hotkey.defaultsKey)
        }
    }

    // MARK: Key name lookup

    /// Best-effort readable name for a virtual key code.
    static func keyName(for keyCode: UInt16) -> String {
        if let special = specialKeys[Int(keyCode)] { return special }

        // Translate via the current keyboard layout for printable keys.
        let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
        guard let layoutData = source.flatMap({
            TISGetInputSourceProperty($0, kTISPropertyUnicodeKeyLayoutData)
        }) else { return "Key \(keyCode)" }

        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)

        let status = data.withUnsafeBytes { raw -> OSStatus in
            let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress!
            return UCKeyTranslate(layout,
                                  keyCode,
                                  UInt16(kUCKeyActionDisplay),
                                  0,
                                  UInt32(LMGetKbdType()),
                                  UInt32(kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeys,
                                  chars.count,
                                  &length,
                                  &chars)
        }
        if status == noErr, length > 0 {
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
        return "Key \(keyCode)"
    }

    private static let specialKeys: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫",
        kVK_Escape: "⎋", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12",
    ]
}
