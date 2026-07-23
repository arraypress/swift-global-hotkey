//
//  CapsLockRemapTests.swift
//  GlobalHotkeyTests
//
//  Only the payload builder is tested — running hidutil would actually remap
//  the tester's keyboard, so the process call is deliberately not exercised.
//

import XCTest
@testable import GlobalHotkey

final class CapsLockRemapTests: XCTestCase {

    func testMappingJSON_capsLockToF18() {
        let json = CapsLockRemap.mappingJSON(from: CapsLockRemap.capsLockUsage, to: CapsLockRemap.f18Usage)
        XCTAssertEqual(
            json,
            "{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":0x700000039,\"HIDKeyboardModifierMappingDst\":0x70000006d}]}"
        )
    }

    func testMappingJSON_arbitrarySrcDst() {
        let json = CapsLockRemap.mappingJSON(from: 0x700000039, to: 0x700000029)
        XCTAssertTrue(json.contains("\"HIDKeyboardModifierMappingSrc\":0x700000039"))
        XCTAssertTrue(json.contains("\"HIDKeyboardModifierMappingDst\":0x700000029"))
    }

    func testClearJSON_isEmptyMapping() {
        XCTAssertEqual(CapsLockRemap.clearJSON, "{\"UserKeyMapping\":[]}")
    }

    func testKnownUsageCodes() {
        XCTAssertEqual(CapsLockRemap.capsLockUsage, 0x700000039)
        XCTAssertEqual(CapsLockRemap.f18Usage, 0x70000006D)
    }
}
