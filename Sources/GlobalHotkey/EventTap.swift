//
//  EventTap.swift
//  GlobalHotkey
//
//  Shared foundation for a session-level global CGEventTap. Subclasses override
//  `handle(type:event:)` to process key events. This base owns the tap's whole
//  lifecycle — creation, run-loop installation, teardown, and the automatic
//  re-enable when the OS disables the tap under load.
//
//  A CGEventTap (not a Carbon hotkey) is used because these hotkeys need
//  key-up, hold-to-activate, and the ability to rewrite/suppress events —
//  none of which `RegisterEventHotKey` provides. The trade-off is that the tap
//  requires Accessibility permission and does not work in a sandboxed app.
//

import AppKit
import ApplicationServices

/// A session-level global `CGEventTap`. Not used directly — subclass it (see
/// ``PushToTalkHotkey`` and ``HyperKey``) and override ``handle(type:event:)``.
public class EventTap {

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public init() {}

    /// The set of event types the tap observes. Subclasses may override; the
    /// default covers key-down, key-up, and modifier changes.
    var eventMask: CGEventMask {
        (1 << CGEventType.keyDown.rawValue) |
        (1 << CGEventType.keyUp.rawValue) |
        (1 << CGEventType.flagsChanged.rawValue)
    }

    /// Whether the event tap is currently installed.
    public var isRunning: Bool { tap != nil }

    // MARK: - Lifecycle

    /// Install the event tap. Returns `false` if it couldn't be created
    /// (usually because Accessibility permission is not granted yet).
    @discardableResult
    public func start() -> Bool {
        guard tap == nil else { return true }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let this = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
            return this.dispatch(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// Uninstall the event tap and reset any subclass state.
    public func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        didStop()
    }

    // MARK: - Subclass hooks

    /// Process an event. Return `nil` to suppress it, or the event (possibly
    /// mutated) to pass it through. Subclasses override this.
    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        Unmanaged.passUnretained(event)
    }

    /// Called after the tap is torn down — reset hold state here.
    func didStop() {}

    /// Called when the OS disabled the tap and it has just been re-enabled —
    /// end any in-flight hold here.
    func tapReenabled() {}

    /// Fire a main-actor callback. The tap's run-loop source is installed on the
    /// main run loop, so the callback is already executing on the main thread.
    func fire(_ handler: (@MainActor () -> Void)?) {
        guard let handler else { return }
        MainActor.assumeIsolated { handler() }
    }

    // MARK: - Private

    private func dispatch(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The OS can disable a tap under load; re-enable and carry on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            tapReenabled()
            return Unmanaged.passUnretained(event)
        }
        return handle(type: type, event: event)
    }
}
