//
//  PushToTalkHotkeyTests.swift
//  GlobalHotkeyTests
//

import XCTest
@testable import GlobalHotkey

final class PushToTalkHotkeyTests: XCTestCase {

    // Control + Option + Space (the default chord).
    private let triggerKey: Int64 = 0x31

    // MARK: - Press

    func testDecide_keyDownWithMatchingChord_whenNotHeld_pressesAndSuppresses() {
        let decision = PushToTalkHotkey.decide(
            type: .keyDown, keyCode: triggerKey, modifiersMatch: true,
            triggerKey: triggerKey, isHeld: false
        )
        XCTAssertEqual(decision, .init(action: .press, suppressEvent: true, isHeld: true))
    }

    func testDecide_keyDownRepeat_whileHeld_firesNothingButStaysHeldAndSuppressed() {
        let decision = PushToTalkHotkey.decide(
            type: .keyDown, keyCode: triggerKey, modifiersMatch: true,
            triggerKey: triggerKey, isHeld: true
        )
        XCTAssertEqual(decision, .init(action: .none, suppressEvent: true, isHeld: true))
    }

    func testDecide_keyDownWithoutModifiers_isIgnored() {
        let decision = PushToTalkHotkey.decide(
            type: .keyDown, keyCode: triggerKey, modifiersMatch: false,
            triggerKey: triggerKey, isHeld: false
        )
        XCTAssertEqual(decision, .init(action: .none, suppressEvent: false, isHeld: false))
    }

    func testDecide_keyDownOfDifferentKey_isIgnored() {
        let decision = PushToTalkHotkey.decide(
            type: .keyDown, keyCode: 0x00, modifiersMatch: true,
            triggerKey: triggerKey, isHeld: false
        )
        XCTAssertEqual(decision, .init(action: .none, suppressEvent: false, isHeld: false))
    }

    // MARK: - Release

    func testDecide_keyUpOfTrigger_whileHeld_releasesAndSuppresses() {
        let decision = PushToTalkHotkey.decide(
            type: .keyUp, keyCode: triggerKey, modifiersMatch: true,
            triggerKey: triggerKey, isHeld: true
        )
        XCTAssertEqual(decision, .init(action: .release, suppressEvent: true, isHeld: false))
    }

    func testDecide_keyUpOfTrigger_whenNotHeld_firesNothingButStillSuppresses() {
        let decision = PushToTalkHotkey.decide(
            type: .keyUp, keyCode: triggerKey, modifiersMatch: false,
            triggerKey: triggerKey, isHeld: false
        )
        XCTAssertEqual(decision, .init(action: .none, suppressEvent: true, isHeld: false))
    }

    func testDecide_modifierReleasedMidHold_releasesAndLetsEventPass() {
        let decision = PushToTalkHotkey.decide(
            type: .flagsChanged, keyCode: 0x3B, modifiersMatch: false,
            triggerKey: triggerKey, isHeld: true
        )
        XCTAssertEqual(decision, .init(action: .release, suppressEvent: false, isHeld: false))
    }

    func testDecide_flagsChangedWhileHeld_withModifiersStillDown_isIgnored() {
        let decision = PushToTalkHotkey.decide(
            type: .flagsChanged, keyCode: 0x3B, modifiersMatch: true,
            triggerKey: triggerKey, isHeld: true
        )
        XCTAssertEqual(decision, .init(action: .none, suppressEvent: false, isHeld: true))
    }

    // MARK: - Full press → release cycle

    func testDecide_pressThenReleaseCycle() {
        let press = PushToTalkHotkey.decide(
            type: .keyDown, keyCode: triggerKey, modifiersMatch: true,
            triggerKey: triggerKey, isHeld: false
        )
        XCTAssertEqual(press.action, .press)
        XCTAssertTrue(press.isHeld)

        let release = PushToTalkHotkey.decide(
            type: .keyUp, keyCode: triggerKey, modifiersMatch: true,
            triggerKey: triggerKey, isHeld: press.isHeld
        )
        XCTAssertEqual(release.action, .release)
        XCTAssertFalse(release.isHeld)
    }

    // MARK: - Configuration & lifecycle

    func testDefaultChord_isControlOptionSpace() {
        let chord = PushToTalkHotkey.Chord.controlOptionSpace
        XCTAssertEqual(chord.keyCode, 0x31)
        XCTAssertTrue(chord.modifiers.contains(.maskControl))
        XCTAssertTrue(chord.modifiers.contains(.maskAlternate))
    }

    func testInit_acceptsCustomChord() {
        let hotkey = PushToTalkHotkey(chord: .init(keyCode: 0x0C, modifiers: [.maskCommand]))
        XCTAssertEqual(hotkey.chord.keyCode, 0x0C)
        XCTAssertTrue(hotkey.chord.modifiers.contains(.maskCommand))
    }

    func testIsRunning_beforeStart_isFalse() {
        XCTAssertFalse(PushToTalkHotkey().isRunning)
    }

    func testStop_whenNotRunning_isANoOp() {
        let hotkey = PushToTalkHotkey()
        hotkey.stop()
        XCTAssertFalse(hotkey.isRunning)
    }

}
