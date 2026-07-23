//
//  CapsLockRemap.swift
//  GlobalHotkey
//
//  Remaps Caps Lock to F18 (or another key) via `hidutil`, so Caps Lock can be
//  used as a ``HyperKey`` trigger. Caps Lock emits a toggle, not a clean
//  key-down/up, so it can't be tapped directly — remapping it to F18 (virtual
//  key `0x4F`) makes it a normal key the event tap can hold-detect.
//
//  The remap is applied at the HID layer and RESETS on reboot or replug —
//  re-apply it on launch (or install a LaunchAgent). No permission needed.
//

import Foundation

/// Remap Caps Lock so it can drive a ``HyperKey``.
public enum CapsLockRemap {

    /// HID usage code for Caps Lock.
    public static let capsLockUsage: UInt64 = 0x700000039

    /// HID usage code for F18 — the recommended remap target (virtual key `0x4F`).
    public static let f18Usage: UInt64 = 0x70000006D

    /// Build the `hidutil` `UserKeyMapping` payload for a src → dst remap.
    static func mappingJSON(from source: UInt64, to destination: UInt64) -> String {
        "{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":0x\(String(source, radix: 16)),\"HIDKeyboardModifierMappingDst\":0x\(String(destination, radix: 16))}]}"
    }

    /// The payload that clears all user key mappings.
    static let clearJSON = "{\"UserKeyMapping\":[]}"

    /// Remap Caps Lock → `destination` (F18 by default). Call on launch, since
    /// the mapping doesn't survive reboot/replug.
    ///
    /// - Returns: `true` if `hidutil` applied the mapping successfully.
    @discardableResult
    public static func remap(to destination: UInt64 = f18Usage) -> Bool {
        run(mappingJSON(from: capsLockUsage, to: destination))
    }

    /// Clear the Caps Lock remap (restore default behavior).
    @discardableResult
    public static func reset() -> Bool {
        run(clearJSON)
    }

    private static func run(_ payload: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", payload]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
