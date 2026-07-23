//
//  GlobalHotkeyStoreTests.swift
//  GlobalHotkeyTests
//

import XCTest
@testable import GlobalHotkey

final class GlobalHotkeyStoreTests: XCTestCase {

    private let suiteName = "GlobalHotkeyStoreTests"
    private var previousDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        previousDefaults = GlobalHotkey.defaults
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        GlobalHotkey.defaults = suite
    }

    override func tearDown() {
        GlobalHotkey.defaults.removePersistentDomain(forName: suiteName)
        GlobalHotkey.defaults = previousDefaults
        super.tearDown()
    }

    func testShortcut_whenUnset_isNil() {
        let name = GlobalHotkey.Name("unset")
        XCTAssertNil(GlobalHotkey.shortcut(for: name))
    }

    func testSetAndGetShortcut_roundTrips() {
        let name = GlobalHotkey.Name("record")
        let shortcut = Shortcut(keyCode: 0x31, modifiers: [.control, .option])

        GlobalHotkey.setShortcut(shortcut, for: name)
        XCTAssertEqual(GlobalHotkey.shortcut(for: name), shortcut)
    }

    func testReset_clearsShortcut() {
        let name = GlobalHotkey.Name("clearme")
        GlobalHotkey.setShortcut(Shortcut(keyCode: 0x24), for: name)
        XCTAssertNotNil(GlobalHotkey.shortcut(for: name))

        GlobalHotkey.reset(name)
        XCTAssertNil(GlobalHotkey.shortcut(for: name))
    }

    func testDistinctNames_doNotCollide() {
        let a = GlobalHotkey.Name("a")
        let b = GlobalHotkey.Name("b")
        GlobalHotkey.setShortcut(Shortcut(keyCode: 0x00), for: a)
        GlobalHotkey.setShortcut(Shortcut(keyCode: 0x0B), for: b)

        XCTAssertEqual(GlobalHotkey.shortcut(for: a)?.keyCode, 0x00)
        XCTAssertEqual(GlobalHotkey.shortcut(for: b)?.keyCode, 0x0B)
    }

    func testOnHold_withNoStoredShortcut_isInactive() {
        let name = GlobalHotkey.Name("nostore")
        let started = GlobalHotkey.onHold(for: name, keyDown: {}, keyUp: {})
        XCTAssertFalse(started)
        XCTAssertFalse(GlobalHotkey.isActive(name))
        GlobalHotkey.disable(name)
    }
}
