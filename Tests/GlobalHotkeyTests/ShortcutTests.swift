//
//  ShortcutTests.swift
//  GlobalHotkeyTests
//

import XCTest
import AppKit
@testable import GlobalHotkey

final class ShortcutTests: XCTestCase {

    func testCodable_roundTrips() throws {
        let shortcut = Shortcut(keyCode: 0x31, modifiers: [.control, .option])
        let data = try JSONEncoder().encode(shortcut)
        let decoded = try JSONDecoder().decode(Shortcut.self, from: data)
        XCTAssertEqual(decoded, shortcut)
    }

    func testInitFromEventModifiers_mapsFlags() {
        let shortcut = Shortcut(keyCode: 0x31, eventModifiers: [.command, .shift, .capsLock])
        XCTAssertTrue(shortcut.modifiers.contains(.command))
        XCTAssertTrue(shortcut.modifiers.contains(.shift))
        XCTAssertFalse(shortcut.modifiers.contains(.control))
        // Caps Lock is not one of our tracked modifiers.
        XCTAssertEqual(shortcut.modifiers, [.command, .shift])
    }

    func testCGEventFlags_mapsAllFour() {
        let shortcut = Shortcut(keyCode: 0x00, modifiers: [.command, .control, .option, .shift])
        let flags = shortcut.cgEventFlags
        XCTAssertTrue(flags.contains(.maskCommand))
        XCTAssertTrue(flags.contains(.maskControl))
        XCTAssertTrue(flags.contains(.maskAlternate))
        XCTAssertTrue(flags.contains(.maskShift))
    }

    func testChord_carriesKeyCodeAndFlags() {
        let shortcut = Shortcut(keyCode: 0x31, modifiers: [.control, .option])
        let chord = shortcut.chord
        XCTAssertEqual(chord.keyCode, 0x31)
        XCTAssertTrue(chord.modifiers.isSuperset(of: [.maskControl, .maskAlternate]))
    }

    func testDisplayString_usesCanonicalOrderAndKeyName() {
        // Order is always ⌃⌥⇧⌘ regardless of insertion order.
        let shortcut = Shortcut(keyCode: 0x31, modifiers: [.command, .control])
        XCTAssertEqual(shortcut.displayString, "⌃⌘Space")
    }

    func testDisplayString_bareKey() {
        XCTAssertEqual(Shortcut(keyCode: 0x4F).displayString, "F18")
    }

    func testKeyName_unknownFallsBack() {
        XCTAssertEqual(Shortcut.keyName(for: 0xFF), "Key 255")
    }
}
