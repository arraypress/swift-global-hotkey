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
- ⌨️ **User-recordable** — a SwiftUI `HotkeyRecorder` field + typed `Name`s + UserDefaults persistence
- 🔤 **Caps Lock helper** — remap Caps Lock → F18 via `hidutil` so it can drive a hyper key
- 🧯 **Robust** — auto re-enables if the OS disables the tap, and ends any in-flight hold
- 🧵 **Main-thread callbacks** — handlers are delivered on the main actor
- 🔐 **Permission helpers** — check, request, and deep-link to Accessibility settings
- 🧪 **Pure, tested state machines** — the hold/hyper decision logic is unit-tested independent of AppKit
- 🪶 **Zero dependencies** — AppKit, SwiftUI, and ApplicationServices only

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

### User-Recordable Shortcuts (SwiftUI)

Let users pick their own shortcut — a typed `Name`, a `HotkeyRecorder` field, automatic UserDefaults persistence, and a managed hotkey that rebuilds itself when the shortcut changes.

```swift
import GlobalHotkey

extension GlobalHotkey.Name {
    static let pushToTalk = Self("pushToTalk")
}

// At startup — reads the stored shortcut and (re)installs the hotkey on change:
GlobalHotkey.onHold(
    for: .pushToTalk,
    keyDown: { startRecording() },
    keyUp: { stopRecording() }
)

// In your Settings UI — click, press your shortcut, it saves itself:
Form {
    LabeledContent("Push to talk") {
        HotkeyRecorder(for: .pushToTalk)
    }
}
```

`⌫` clears the shortcut, `⎋` cancels recording. To store in a shared app-group suite, set `GlobalHotkey.defaults` before use.

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

Caps Lock emits a toggle (`flagsChanged`), not a clean key-down/up, so it can't be a trigger directly. Remap it to F18 (virtual key `0x4F`) with the built-in helper, then use `0x4F` as the trigger:

```swift
CapsLockRemap.remap()                 // Caps Lock → F18 (call on launch)
let hyper = HyperKey(triggerKey: 0x4F, tapKey: 0x35)  // tap still types Escape
// CapsLockRemap.reset()              // restore default Caps Lock behavior
```

The remap is applied at the HID layer and **resets on reboot/replug** (no permission needed), so call `CapsLockRemap.remap()` on app launch, or install a `LaunchAgent` to persist it.

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
plus the `Shortcut` model, UserDefaults persistence, the `hidutil` payload,
configuration, bindings, and lifecycle.

## License

MIT License — see LICENSE file for details.

## Author

Created by David Sherlock ([ArrayPress](https://github.com/arraypress)) in 2026.
