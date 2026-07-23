//
//  PushToTalkHotkey.swift
//  GlobalHotkey
//
//  A global, hold-to-talk hotkey: fires `onPress` when the configured key +
//  modifier chord goes down, and `onRelease` when the chord ends (the trigger
//  key comes up, a required modifier is released mid-hold, or the tap is
//  disabled). While held, the trigger key is suppressed so it doesn't also
//  type or scroll in the frontmost app.
//

import AppKit
import ApplicationServices

/// A global, hold-to-talk hotkey.
///
/// ## Example
///
/// ```swift
/// let hotkey = PushToTalkHotkey()          // Control + Option + Space
/// hotkey.onPress = { startRecording() }
/// hotkey.onRelease = { stopRecording() }
///
/// guard hotkey.start() else {
///     AccessibilityPermission.request()
///     return
/// }
/// ```
public final class PushToTalkHotkey: EventTap {

    /// The key + modifier chord that triggers the hotkey.
    public struct Chord {

        /// The virtual key code of the trigger key (e.g. `0x31` for Space).
        public var keyCode: Int64

        /// The modifier flags that must be held together with the trigger key.
        public var modifiers: CGEventFlags

        /// Create a chord from a trigger key and its required modifiers.
        public init(keyCode: Int64, modifiers: CGEventFlags) {
            self.keyCode = keyCode
            self.modifiers = modifiers
        }

        /// Hold **Control + Option + Space** — the default push-to-talk chord.
        public static let controlOptionSpace = Chord(
            keyCode: 0x31,
            modifiers: [.maskControl, .maskAlternate]
        )
    }

    /// Called on the main thread when the chord goes down.
    public var onPress: (@MainActor () -> Void)?

    /// Called on the main thread when the chord is released.
    public var onRelease: (@MainActor () -> Void)?

    /// The chord this hotkey listens for.
    public let chord: Chord

    private var isHeld = false

    /// Create a hotkey for `chord` (defaults to Control + Option + Space).
    public init(chord: Chord = .controlOptionSpace) {
        self.chord = chord
    }

    // MARK: - Event Handling

    override func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let modifiersMatch = event.flags.isSuperset(of: chord.modifiers)
        let decision = Self.decide(
            type: type,
            keyCode: keyCode,
            modifiersMatch: modifiersMatch,
            triggerKey: chord.keyCode,
            isHeld: isHeld
        )

        isHeld = decision.isHeld
        switch decision.action {
        case .press: fire(onPress)
        case .release: fire(onRelease)
        case .none: break
        }
        return decision.suppressEvent ? nil : Unmanaged.passUnretained(event)
    }

    override func didStop() {
        isHeld = false
    }

    override func tapReenabled() {
        if isHeld { isHeld = false; fire(onRelease) }
    }

    // MARK: - Hold State Machine (pure, testable)

    /// What the hold state machine should do in response to an event.
    enum Action: Equatable {
        /// The chord went down — the hold has begun.
        case press
        /// The chord ended — the hold is over.
        case release
        /// Nothing to fire.
        case none
    }

    /// The outcome of feeding one event to the hold state machine.
    struct Decision: Equatable {
        /// The handler to fire, if any.
        let action: Action
        /// Whether the event should be swallowed (not passed to the app).
        let suppressEvent: Bool
        /// The resulting hold state.
        let isHeld: Bool
    }

    /// Pure decision function for the hold state machine. Kept free of AppKit
    /// event objects so it can be exhaustively unit-tested.
    static func decide(
        type: CGEventType,
        keyCode: Int64,
        modifiersMatch: Bool,
        triggerKey: Int64,
        isHeld: Bool
    ) -> Decision {
        switch type {
        case .keyDown where keyCode == triggerKey && modifiersMatch:
            // Begin the hold on the first matching key-down; suppress the key so
            // it doesn't also type/scroll. Repeats while held fire nothing.
            return Decision(action: isHeld ? .none : .press, suppressEvent: true, isHeld: true)

        case .keyUp where keyCode == triggerKey:
            // The trigger key-up ends the hold and is always suppressed.
            return Decision(action: isHeld ? .release : .none, suppressEvent: true, isHeld: false)

        case .flagsChanged where isHeld && !modifiersMatch:
            // A required modifier was released mid-hold — end the hold, but let
            // the modifier event itself pass through.
            return Decision(action: .release, suppressEvent: false, isHeld: false)

        default:
            return Decision(action: .none, suppressEvent: false, isHeld: isHeld)
        }
    }
}
