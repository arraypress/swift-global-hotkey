//
//  HyperKeyTests.swift
//  GlobalHotkeyTests
//

import XCTest
@testable import GlobalHotkey

final class HyperKeyTests: XCTestCase {

    private let trigger: Int64 = 0x4F   // F18 (typical Caps-Lock-remap target)
    private let tapKey: Int64 = 0x35    // Escape
    private let someKey: Int64 = 0x0B   // B

    // MARK: - Activation

    func testDecide_triggerDown_whenInactive_activatesAndSuppresses() {
        let d = HyperKey.decide(
            type: .keyDown, keyCode: trigger, isActive: false, usedAsModifier: false,
            triggerKey: trigger, hasTapKey: true, isBound: false
        )
        XCTAssertEqual(d, .init(action: .activate, isActive: true, usedAsModifier: false, suppressEvent: true))
    }

    func testDecide_triggerDownRepeat_whileActive_firesNothingButStaysActiveAndSuppressed() {
        let d = HyperKey.decide(
            type: .keyDown, keyCode: trigger, isActive: true, usedAsModifier: true,
            triggerKey: trigger, hasTapKey: true, isBound: false
        )
        XCTAssertEqual(d, .init(action: .none, isActive: true, usedAsModifier: true, suppressEvent: true))
    }

    // MARK: - Deactivation & dual-role tap

    func testDecide_triggerUp_afterQuickTap_emitsTapKey() {
        let d = HyperKey.decide(
            type: .keyUp, keyCode: trigger, isActive: true, usedAsModifier: false,
            triggerKey: trigger, hasTapKey: true, isBound: false
        )
        XCTAssertEqual(d, .init(action: .deactivate(emitTap: true), isActive: false, usedAsModifier: false, suppressEvent: true))
    }

    func testDecide_triggerUp_afterUsedAsModifier_doesNotEmitTapKey() {
        let d = HyperKey.decide(
            type: .keyUp, keyCode: trigger, isActive: true, usedAsModifier: true,
            triggerKey: trigger, hasTapKey: true, isBound: false
        )
        XCTAssertEqual(d, .init(action: .deactivate(emitTap: false), isActive: false, usedAsModifier: false, suppressEvent: true))
    }

    func testDecide_triggerUp_withNoTapKey_doesNotEmit() {
        let d = HyperKey.decide(
            type: .keyUp, keyCode: trigger, isActive: true, usedAsModifier: false,
            triggerKey: trigger, hasTapKey: false, isBound: false
        )
        XCTAssertEqual(d, .init(action: .deactivate(emitTap: false), isActive: false, usedAsModifier: false, suppressEvent: true))
    }

    // MARK: - Bound chords

    func testDecide_boundKeyDown_whileActive_firesBindingAndSuppresses() {
        let d = HyperKey.decide(
            type: .keyDown, keyCode: someKey, isActive: true, usedAsModifier: false,
            triggerKey: trigger, hasTapKey: true, isBound: true
        )
        XCTAssertEqual(d, .init(action: .fireBinding(keyCode: someKey), isActive: true, usedAsModifier: true, suppressEvent: true))
    }

    func testDecide_boundKeyUp_whileActive_isSuppressedWithNoAction() {
        let d = HyperKey.decide(
            type: .keyUp, keyCode: someKey, isActive: true, usedAsModifier: true,
            triggerKey: trigger, hasTapKey: true, isBound: true
        )
        XCTAssertEqual(d, .init(action: .none, isActive: true, usedAsModifier: true, suppressEvent: true))
    }

    // MARK: - Unbound keys get the hyper modifiers

    func testDecide_unboundKeyDown_whileActive_injectsHyperAndPasses() {
        let d = HyperKey.decide(
            type: .keyDown, keyCode: someKey, isActive: true, usedAsModifier: false,
            triggerKey: trigger, hasTapKey: true, isBound: false
        )
        XCTAssertEqual(d, .init(action: .injectHyper, isActive: true, usedAsModifier: true, suppressEvent: false))
    }

    func testDecide_unboundKeyUp_whileActive_injectsHyperAndPasses() {
        let d = HyperKey.decide(
            type: .keyUp, keyCode: someKey, isActive: true, usedAsModifier: true,
            triggerKey: trigger, hasTapKey: true, isBound: false
        )
        XCTAssertEqual(d, .init(action: .injectHyper, isActive: true, usedAsModifier: true, suppressEvent: false))
    }

    // MARK: - Inactive passthrough

    func testDecide_keyWhileInactive_passesThroughUntouched() {
        let d = HyperKey.decide(
            type: .keyDown, keyCode: someKey, isActive: false, usedAsModifier: false,
            triggerKey: trigger, hasTapKey: true, isBound: false
        )
        XCTAssertEqual(d, .init(action: .none, isActive: false, usedAsModifier: false, suppressEvent: false))
    }

    // MARK: - Full cycles

    func testDecide_holdThenBoundChord_thenReleaseWithoutTap() {
        let activate = HyperKey.decide(
            type: .keyDown, keyCode: trigger, isActive: false, usedAsModifier: false,
            triggerKey: trigger, hasTapKey: true, isBound: false
        )
        XCTAssertEqual(activate.action, .activate)

        let chord = HyperKey.decide(
            type: .keyDown, keyCode: someKey, isActive: activate.isActive, usedAsModifier: activate.usedAsModifier,
            triggerKey: trigger, hasTapKey: true, isBound: true
        )
        XCTAssertEqual(chord.action, .fireBinding(keyCode: someKey))
        XCTAssertTrue(chord.usedAsModifier)

        let release = HyperKey.decide(
            type: .keyUp, keyCode: trigger, isActive: chord.isActive, usedAsModifier: chord.usedAsModifier,
            triggerKey: trigger, hasTapKey: true, isBound: false
        )
        XCTAssertEqual(release.action, .deactivate(emitTap: false))
        XCTAssertFalse(release.isActive)
    }

    func testDecide_holdThenReleaseWithNothingPressed_emitsTap() {
        let activate = HyperKey.decide(
            type: .keyDown, keyCode: trigger, isActive: false, usedAsModifier: false,
            triggerKey: trigger, hasTapKey: true, isBound: false
        )
        let release = HyperKey.decide(
            type: .keyUp, keyCode: trigger, isActive: activate.isActive, usedAsModifier: activate.usedAsModifier,
            triggerKey: trigger, hasTapKey: true, isBound: false
        )
        XCTAssertEqual(release.action, .deactivate(emitTap: true))
    }

    // MARK: - Configuration

    func testHyperFlags_containsAllFourModifiers() {
        let flags = HyperKey.hyperFlags
        XCTAssertTrue(flags.contains(.maskCommand))
        XCTAssertTrue(flags.contains(.maskControl))
        XCTAssertTrue(flags.contains(.maskAlternate))
        XCTAssertTrue(flags.contains(.maskShift))
    }

    func testInit_storesTriggerAndTapKey() {
        let hyper = HyperKey(triggerKey: trigger, tapKey: tapKey)
        XCTAssertEqual(hyper.triggerKey, trigger)
        XCTAssertEqual(hyper.tapKey, tapKey)
    }

    func testInit_tapKeyDefaultsToNil() {
        XCTAssertNil(HyperKey(triggerKey: trigger).tapKey)
    }

    // MARK: - Bindings

    func testBindAndUnbind_updateBoundKeyCodes() {
        let hyper = HyperKey(triggerKey: trigger)
        XCTAssertTrue(hyper.boundKeyCodes.isEmpty)

        hyper.bind(someKey) {}
        XCTAssertEqual(hyper.boundKeyCodes, [someKey])

        hyper.unbind(someKey)
        XCTAssertTrue(hyper.boundKeyCodes.isEmpty)
    }

    // MARK: - Lifecycle

    func testIsRunning_beforeStart_isFalse() {
        XCTAssertFalse(HyperKey(triggerKey: trigger).isRunning)
    }

    func testStop_whenNotRunning_isANoOp() {
        let hyper = HyperKey(triggerKey: trigger)
        hyper.stop()
        XCTAssertFalse(hyper.isRunning)
    }

}
