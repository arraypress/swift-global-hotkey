//
//  AccessibilityPermission.swift
//  GlobalHotkey
//
//  Accessibility (TCC) permission helpers. Installing a global event tap
//  requires Accessibility permission, so every hotkey type here needs it.
//

import AppKit
import ApplicationServices

/// Accessibility permission helpers, required to tap global key events.
public enum AccessibilityPermission {

    /// Whether Accessibility permission is currently granted.
    public static var isGranted: Bool {
        return AXIsProcessTrusted()
    }

    /// Request Accessibility permission from the user.
    ///
    /// Shows the system prompt. The app may need a restart after granting —
    /// and for an unsigned ad-hoc build, the grant is tied to the exact binary,
    /// so a rebuild can invalidate it (toggle it off/on in System Settings).
    public static func request() {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Open System Settings to the Accessibility preferences pane.
    public static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
