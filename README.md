# Swift Global Hotkey

A tiny Swift library for **global keyboard hotkeys on macOS** built on a single `CGEventTap` foundation. Two modes on the same engine:

- **Push-to-talk** — hold a chord, get press/release callbacks (for dictation, voice capture, walkie-talkie UIs).
- **Hyper key** — hold one trigger key and every other key arrives stamped with all four modifiers (⌘⌃⌥⇧), a fresh hotkey layer that never collides with system or app shortcuts.

Unlike Carbon `RegisterEventHotKey`-based libraries, an event tap gets you **key-up, hold-to-activate, dual-role keys, and modifier injection** — at the cost of requiring Accessibility permission (so this is **not** for sandboxed / Mac App Store apps).

## Features

- 🎙️ **Push-to-talk** — `onPress` / `onRelease` on a configurable key + modifier chord
- ✨ **Hyper key** — turn one key into ⌘⌃⌥⇧, with direct chord bindings
- 🔁 **Dual-role** — a quick tap of the hyper trigger can emit a fallback key (e.g. Caps Lock → Escape)
- 🤫 **Key suppression** — the trigger key is swallowed so it doesn't type or scroll
- 🧯 **Robust** — auto re-enables if the OS disables the tap, and ends any in-flight hold
- 🧵 **Main-thread callbacks** — handlers are delivered on the main actor
- 🔐 **Permission helpers** — check, request, and deep-link to Accessibility settings
- 🧪 **Pure, tested state machines** — the hold/hyper decision logic is unit-tested independent of AppKit
- 🪶 **Zero dependencies** — AppKit and ApplicationServices only

## Requirements

- macOS 13.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-global-hotkey.git", from: "1.0.0")
]
```

## Usage

### Push-to-Talk

```swift
import GlobalHotkey

let hotkey = PushToTalkHotkey()          // Control + Option + Space
hotkey.onPress = { startRecording() }
hotkey.onRelease = { stopRecording() }

guard hotkey.start() else {
    AccessibilityPermission.request()
    return
}
```

A custom chord:

```swift
let hotkey = PushToTalkHotkey(chord: .init(keyCode: 0x0C, modifiers: [.maskCommand])) // hold ⌘Q
```

### Hyper Key

```swift
import GlobalHotkey

// Caps Lock remapped to F18 (0x4F) via hidutil; a quick tap still types Escape (0x35).
let hyper = HyperKey(triggerKey: 0x4F, tapKey: 0x35)
hyper.bind(0x0B) { openBrowser() }   // Hyper + B
hyper.bind(0x2E) { openMail() }      // Hyper + M

guard hyper.start() else {
    AccessibilityPermission.request()
    return
}
```

Keys you don't bind are passed through with the four modifiers applied, so anything else listening for the hyper combo still works.

### Caps Lock as the trigger

Caps Lock emits a toggle (`flagsChanged`), not a clean key-down/up, so it can't be a trigger directly. Remap it to F18 first with `hidutil`, then use `0x4F` as the trigger:

```bash
hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x70000006D}]}'
```

The remap resets on reboot/replug — persist it with a `LaunchAgent` or re-apply on app launch. (A built-in Caps Lock helper is on the roadmap.)

### Accessibility Permission

Tapping key events requires Accessibility permission.

```swift
if !AccessibilityPermission.isGranted {
    AccessibilityPermission.request()     // shows the system prompt
    AccessibilityPermission.openSettings() // or jump straight to the settings pane
}
```

## How It Works

Both modes share one session-level `CGEventTap` (`EventTap`) that watches
`keyDown` / `keyUp` / `flagsChanged`, re-enables itself if the OS disables the
tap under load, and delivers callbacks on the main run loop. Each mode's core
logic — when to fire, what to suppress, when to inject modifiers — is a **pure
decision function** kept free of AppKit event objects, so it can be exhaustively
unit-tested. Hyper injection mutates the passing event's `flags`; the dual-role
tap synthesizes the fallback key with a private-state `CGEventSource`.

A session event tap also sees events while a menu is open, so — unlike Carbon
hotkeys — no separate menu-mode fallback is needed.

## Testing

```bash
swift test
```

Tests exhaustively cover both state machines — press/repeat/release, dropped
modifiers, dual-role tap emission, bound vs unbound keys, and suppression —
plus configuration, bindings, and lifecycle.

## License

MIT License — see LICENSE file for details.

## Author

Created by David Sherlock ([ArrayPress](https://github.com/arraypress)) in 2026.
