//
//  HyperKey.swift
//  GlobalHotkey
//
//  A "hyper key": hold a single trigger key and every other key you press is
//  stamped with all four modifiers (⌘⌃⌥⇧) — a fresh hotkey layer that never
//  collides with system or app shortcuts. Bind actions directly to hyper-chords,
//  or let the stamped events flow through so anything else listening for the
//  hyper combo still works. Optionally dual-role: a quick tap of the trigger
//  (with no other key) emits a fallback key instead.
//
//  Note on Caps Lock: Caps Lock emits a toggle (`flagsChanged`), not a clean
//  key-down/up, so it can't be a trigger directly. The usual path is to remap
//  Caps Lock → F18 via `hidutil` first, then use F18 (0x4F) as the trigger.
//
//  Requires Accessibility permission (to tap and rewrite key events).
//

import AppKit
import ApplicationServices

/// A global hyper key — hold the trigger, and other keys arrive as ⌘⌃⌥⇧ chords.
///
/// ## Example
///
/// ```swift
/// // Caps Lock remapped to F18 (0x4F) via hidutil; tap still types Escape (0x35).
/// let hyper = HyperKey(triggerKey: 0x4F, tapKey: 0x35)
/// hyper.bind(0x0B) { openBrowser() }   // Hyper + B
/// hyper.bind(0x2E) { openMail() }      // Hyper + M
///
/// guard hyper.start() else {
///     AccessibilityPermission.request()
///     return
/// }
/// ```
public final class HyperKey: EventTap {

    /// The four modifiers stamped onto other keys while the trigger is held.
    public static let hyperFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

    /// The virtual key code that activates hyper while held.
    public let triggerKey: Int64

    /// The key emitted as a normal tap when the trigger is pressed and released
    /// quickly with no other key in between (dual-role). `nil` disables it.
    public let tapKey: Int64?

    private var bindings: [Int64: @MainActor () -> Void] = [:]
    private var isActive = false
    private var usedAsModifier = false

    /// Create a hyper key.
    ///
    /// - Parameters:
    ///   - triggerKey: The virtual key code to hold for hyper (e.g. `0x4F` = F18).
    ///   - tapKey: Optional dual-role fallback emitted on a quick tap.
    public init(triggerKey: Int64, tapKey: Int64? = nil) {
        self.triggerKey = triggerKey
        self.tapKey = tapKey
    }

    // MARK: - Bindings

    /// Bind an action to a hyper-chord (fired on the main thread).
    public func bind(_ keyCode: Int64, handler: @escaping @MainActor () -> Void) {
        bindings[keyCode] = handler
    }

    /// Remove a hyper-chord binding.
    public func unbind(_ keyCode: Int64) {
        bindings[keyCode] = nil
    }

    /// The key codes that currently have a bound action.
    var boundKeyCodes: Set<Int64> { Set(bindings.keys) }

    // MARK: - Event Handling

    override func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let decision = Self.decide(
            type: type,
            keyCode: keyCode,
            isActive: isActive,
            usedAsModifier: usedAsModifier,
            triggerKey: triggerKey,
            hasTapKey: tapKey != nil,
            isBound: bindings[keyCode] != nil
        )

        isActive = decision.isActive
        usedAsModifier = decision.usedAsModifier

        switch decision.action {
        case .activate, .none:
            break
        case .deactivate(let emitTap):
            if emitTap, let tapKey { emitTapKey(tapKey) }
        case .fireBinding(let code):
            fire(bindings[code])
        case .injectHyper:
            event.flags = event.flags.union(Self.hyperFlags)
        }

        return decision.suppressEvent ? nil : Unmanaged.passUnretained(event)
    }

    override func didStop() {
        isActive = false
        usedAsModifier = false
    }

    override func tapReenabled() {
        isActive = false
        usedAsModifier = false
    }

    private func emitTapKey(_ keyCode: Int64) {
        let source = CGEventSource(stateID: .privateState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    // MARK: - State Machine (pure, testable)

    /// What the hyper state machine should do in response to an event.
    enum Action: Equatable {
        /// The trigger went down — hyper is now active.
        case activate
        /// The trigger came up — hyper is off. `emitTap` is true when the
        /// dual-role tap key should be emitted (quick tap, nothing else pressed).
        case deactivate(emitTap: Bool)
        /// A bound hyper-chord fired.
        case fireBinding(keyCode: Int64)
        /// An unbound key while active — stamp it with the hyper modifiers.
        case injectHyper
        /// Nothing to do.
        case none
    }

    /// The outcome of feeding one event to the hyper state machine.
    struct Decision: Equatable {
        let action: Action
        let isActive: Bool
        let usedAsModifier: Bool
        let suppressEvent: Bool
    }

    /// Pure decision function for the hyper state machine. Kept free of AppKit
    /// event objects so it can be exhaustively unit-tested.
    static func decide(
        type: CGEventType,
        keyCode: Int64,
        isActive: Bool,
        usedAsModifier: Bool,
        triggerKey: Int64,
        hasTapKey: Bool,
        isBound: Bool
    ) -> Decision {
        // The trigger key itself: activate on down, deactivate on up. Always
        // suppressed so it never types.
        if keyCode == triggerKey {
            switch type {
            case .keyDown:
                return Decision(
                    action: isActive ? .none : .activate,
                    isActive: true,
                    usedAsModifier: usedAsModifier && isActive,
                    suppressEvent: true
                )
            case .keyUp:
                let emitTap = isActive && !usedAsModifier && hasTapKey
                return Decision(
                    action: .deactivate(emitTap: emitTap),
                    isActive: false,
                    usedAsModifier: false,
                    suppressEvent: true
                )
            default:
                return Decision(action: .none, isActive: isActive, usedAsModifier: usedAsModifier, suppressEvent: false)
            }
        }

        // Any other key while hyper is active.
        guard isActive else {
            return Decision(action: .none, isActive: false, usedAsModifier: false, suppressEvent: false)
        }

        switch type {
        case .keyDown:
            if isBound {
                // Fire the bound action and swallow the key.
                return Decision(action: .fireBinding(keyCode: keyCode), isActive: true, usedAsModifier: true, suppressEvent: true)
            }
            // Stamp the hyper modifiers and let it flow to the app.
            return Decision(action: .injectHyper, isActive: true, usedAsModifier: true, suppressEvent: false)

        case .keyUp:
            if isBound {
                // The key-down was swallowed; swallow its key-up too.
                return Decision(action: .none, isActive: true, usedAsModifier: true, suppressEvent: true)
            }
            return Decision(action: .injectHyper, isActive: true, usedAsModifier: true, suppressEvent: false)

        default:
            return Decision(action: .none, isActive: true, usedAsModifier: usedAsModifier, suppressEvent: false)
        }
    }
}
