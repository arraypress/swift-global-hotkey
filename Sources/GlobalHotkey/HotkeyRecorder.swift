//
//  HotkeyRecorder.swift
//  GlobalHotkey
//
//  A SwiftUI control that records a shortcut for a `GlobalHotkey.Name` and
//  persists it — the equivalent of KeyboardShortcuts' Recorder, but wired to
//  this package's engine. Click it, press your shortcut. ⌫ clears, ⎋ cancels.
//

#if canImport(SwiftUI) && canImport(AppKit)

import SwiftUI
import AppKit

/// A SwiftUI field that records and stores the shortcut for a ``GlobalHotkey/Name``.
///
/// ```swift
/// Form {
///     LabeledContent("Push to talk") {
///         HotkeyRecorder(for: .pushToTalk)
///     }
/// }
/// ```
public struct HotkeyRecorder: View {

    private let name: GlobalHotkey.Name
    @State private var shortcut: Shortcut?

    /// Create a recorder bound to `name`. It loads the stored shortcut and
    /// persists any change (which also rebuilds a managed hotkey, if registered).
    public init(for name: GlobalHotkey.Name) {
        self.name = name
        _shortcut = State(initialValue: GlobalHotkey.shortcut(for: name))
    }

    public var body: some View {
        RecorderField(shortcut: shortcut) { newValue in
            GlobalHotkey.setShortcut(newValue, for: name)
            shortcut = newValue
        }
        .frame(minWidth: 130, minHeight: 24)
        .fixedSize()
    }
}

// MARK: - AppKit bridge

private struct RecorderField: NSViewRepresentable {
    let shortcut: Shortcut?
    let onChange: (Shortcut?) -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.shortcut = shortcut
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.onChange = onChange
        nsView.shortcut = shortcut
    }
}

/// The first-responder view that captures a key chord.
final class RecorderNSView: NSView {

    var onChange: ((Shortcut?) -> Void)?
    var shortcut: Shortcut? { didSet { needsDisplay = true } }

    private var isRecording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            stopRecording()
        } else {
            isRecording = true
            window?.makeFirstResponder(self)
        }
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    private func stopRecording() {
        isRecording = false
        window?.makeFirstResponder(nil)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }

        switch Int(event.keyCode) {
        case 0x35: // Escape — cancel, keep current
            stopRecording()
        case 0x33: // Delete — clear
            shortcut = nil
            onChange?(nil)
            stopRecording()
        default:
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let captured = Shortcut(keyCode: Int(event.keyCode), eventModifiers: mods)
            shortcut = captured
            onChange?(captured)
            stopRecording()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let frame = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: frame, xRadius: 5, yRadius: 5)

        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        path.lineWidth = 1
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.stroke()

        let text: String
        let isPlaceholder: Bool
        if isRecording {
            text = "Type shortcut…"; isPlaceholder = true
        } else if let shortcut {
            text = shortcut.displayString; isPlaceholder = false
        } else {
            text = "Record Shortcut"; isPlaceholder = true
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: isPlaceholder ? NSColor.secondaryLabelColor : NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textHeight = attributed.size().height
        let textRect = NSRect(x: 0, y: (bounds.height - textHeight) / 2, width: bounds.width, height: textHeight)
        attributed.draw(in: textRect)
    }
}

#endif
