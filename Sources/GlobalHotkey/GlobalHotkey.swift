//
//  GlobalHotkey.swift
//  GlobalHotkey
//
//  The user-facing config layer: strongly-typed shortcut `Name`s, UserDefaults
//  persistence, and a managed push-to-talk registration that (re)builds the
//  running hotkey whenever its stored shortcut changes. Modeled on the
//  ergonomics of sindresorhus/KeyboardShortcuts, but driven by this package's
//  CGEventTap engine instead of Carbon.
//

import Foundation

/// Namespace for named, persisted, user-recordable hotkeys.
///
/// ```swift
/// extension GlobalHotkey.Name {
///     static let pushToTalk = Self("pushToTalk")
/// }
///
/// // Somewhere at startup:
/// GlobalHotkey.onHold(
///     for: .pushToTalk,
///     keyDown: { startRecording() },
///     keyUp: { stopRecording() }
/// )
///
/// // In Settings, let the user record it:
/// HotkeyRecorder(for: .pushToTalk)
/// ```
public enum GlobalHotkey {

    /// A strongly-typed identifier for a stored hotkey.
    public struct Name: Hashable, Sendable {
        public let rawValue: String
        public init(_ rawValue: String) { self.rawValue = rawValue }
    }

    // MARK: - Persistence

    /// The `UserDefaults` shortcuts are stored in. Override before use to point
    /// at a shared app-group suite (or a throwaway suite in tests).
    public static var defaults: UserDefaults = .standard

    private static let keyPrefix = "GlobalHotkey_"

    private static func storageKey(for name: Name) -> String { keyPrefix + name.rawValue }

    /// The shortcut currently stored for `name`, if any.
    public static func shortcut(for name: Name) -> Shortcut? {
        guard let data = defaults.data(forKey: storageKey(for: name)) else { return nil }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
    }

    /// Store (or clear, with `nil`) the shortcut for `name`, then rebuild any
    /// managed hotkey registered under it.
    public static func setShortcut(_ shortcut: Shortcut?, for name: Name) {
        let key = storageKey(for: name)
        if let shortcut, let data = try? JSONEncoder().encode(shortcut) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        reload(name)
    }

    /// Clear the stored shortcut for `name`.
    public static func reset(_ name: Name) {
        setShortcut(nil, for: name)
    }

    // MARK: - Managed push-to-talk registration

    private static var handlers: [Name: (down: @MainActor () -> Void, up: @MainActor () -> Void)] = [:]
    private static var active: [Name: PushToTalkHotkey] = [:]

    /// Register hold-to-talk handlers for `name`. The running hotkey uses the
    /// currently-stored shortcut and is rebuilt automatically whenever the
    /// shortcut changes (e.g. via ``HotkeyRecorder``).
    ///
    /// - Returns: `true` if a hotkey is now installed (a shortcut is stored and
    ///   Accessibility permission is granted).
    @discardableResult
    public static func onHold(
        for name: Name,
        keyDown: @escaping @MainActor () -> Void,
        keyUp: @escaping @MainActor () -> Void
    ) -> Bool {
        handlers[name] = (keyDown, keyUp)
        return reload(name)
    }

    /// Stop and remove the managed hotkey for `name` (keeps the stored shortcut).
    public static func disable(_ name: Name) {
        active[name]?.stop()
        active.removeValue(forKey: name)
    }

    /// Whether a managed hotkey is currently installed for `name`.
    public static func isActive(_ name: Name) -> Bool {
        active[name]?.isRunning ?? false
    }

    @discardableResult
    private static func reload(_ name: Name) -> Bool {
        active[name]?.stop()
        active.removeValue(forKey: name)

        guard let shortcut = shortcut(for: name), let handler = handlers[name] else {
            return false
        }

        let hotkey = PushToTalkHotkey(chord: shortcut.chord)
        hotkey.onPress = handler.down
        hotkey.onRelease = handler.up
        let started = hotkey.start()
        active[name] = hotkey
        return started
    }
}
