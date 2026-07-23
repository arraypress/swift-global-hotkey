//
//  Shortcut.swift
//  GlobalHotkey
//
//  A recorded, persistable key + modifier shortcut. Stores its own stable
//  modifier representation (so it round-trips cleanly through Codable), and
//  bridges to the CGEventFlags the engine uses plus a display string.
//

import AppKit
import CoreGraphics

/// A key code plus modifier flags — the thing a recorder captures and persists.
public struct Shortcut: Codable, Hashable, Sendable {

    /// Stable, Codable modifier set (independent of NSEvent/CGEvent bit layouts).
    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let control = Modifiers(rawValue: 1 << 1)
        public static let option  = Modifiers(rawValue: 1 << 2)
        public static let shift   = Modifiers(rawValue: 1 << 3)
    }

    /// The virtual key code (e.g. `0x31` for Space).
    public var keyCode: Int

    /// The modifiers required alongside the key.
    public var modifiers: Modifiers

    /// Create a shortcut from a key code and modifiers.
    public init(keyCode: Int, modifiers: Modifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Create a shortcut from a recorded key code and AppKit modifier flags.
    public init(keyCode: Int, eventModifiers: NSEvent.ModifierFlags) {
        var mods: Modifiers = []
        if eventModifiers.contains(.command) { mods.insert(.command) }
        if eventModifiers.contains(.control) { mods.insert(.control) }
        if eventModifiers.contains(.option)  { mods.insert(.option) }
        if eventModifiers.contains(.shift)   { mods.insert(.shift) }
        self.init(keyCode: keyCode, modifiers: mods)
    }

    // MARK: - Bridging

    /// The engine-facing `CGEventFlags` for these modifiers.
    public var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option)  { flags.insert(.maskAlternate) }
        if modifiers.contains(.shift)   { flags.insert(.maskShift) }
        return flags
    }

    /// This shortcut as a ``PushToTalkHotkey/Chord``.
    public var chord: PushToTalkHotkey.Chord {
        PushToTalkHotkey.Chord(keyCode: Int64(keyCode), modifiers: cgEventFlags)
    }

    /// A human-readable string like `⌃⌥⌘Space`.
    public var displayString: String {
        var out = ""
        if modifiers.contains(.control) { out += "⌃" }
        if modifiers.contains(.option)  { out += "⌥" }
        if modifiers.contains(.shift)   { out += "⇧" }
        if modifiers.contains(.command) { out += "⌘" }
        out += Self.keyName(for: keyCode)
        return out
    }

    // MARK: - Key names

    /// A readable name for a virtual key code, falling back to `Key NN`.
    static func keyName(for keyCode: Int) -> String {
        if let name = keyNames[keyCode] { return name }
        return "Key \(keyCode)"
    }

    private static let keyNames: [Int: String] = [
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E", 0x03: "F",
        0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J", 0x28: "K", 0x25: "L",
        0x2E: "M", 0x2D: "N", 0x1F: "O", 0x23: "P", 0x0C: "Q", 0x0F: "R",
        0x01: "S", 0x11: "T", 0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X",
        0x10: "Y", 0x06: "Z",
        0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5", 0x16: "6",
        0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
        0x31: "Space", 0x24: "Return", 0x30: "Tab", 0x35: "Escape",
        0x33: "Delete", 0x75: "Forward Delete",
        0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
        0x73: "Home", 0x77: "End", 0x74: "Page Up", 0x79: "Page Down",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6",
        0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        0x69: "F13", 0x6B: "F14", 0x71: "F15", 0x6A: "F16", 0x40: "F17",
        0x4F: "F18", 0x50: "F19", 0x5A: "F20",
    ]
}
