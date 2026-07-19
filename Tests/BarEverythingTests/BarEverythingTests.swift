import CoreGraphics
import XCTest
@testable import BarEverything

final class BarEverythingTests: XCTestCase {
    func testStatusItemFilterRejectsStatusLevelPopovers() {
        let level = Int(CGWindowLevelForKey(.statusWindow))
        XCTAssertTrue(MenuBarItemSnapshot.isStatusItem(layer: level, frame: CGRect(x: 0, y: 0, width: 32, height: 33)))
        XCTAssertFalse(MenuBarItemSnapshot.isStatusItem(layer: level, frame: CGRect(x: 0, y: 0, width: 254, height: 254)))
        XCTAssertFalse(MenuBarItemSnapshot.isStatusItem(layer: 0, frame: CGRect(x: 0, y: 0, width: 32, height: 33)))
    }

    func testOnlyAppleProcessesAreSystemFixed() {
        XCTAssertTrue(MenuBarModel.isSystemFixed(bundleIdentifier: "com.apple.controlcenter"))
        XCTAssertFalse(MenuBarModel.isSystemFixed(bundleIdentifier: "com.todesktop.230313mzl4w4u92"))
        XCTAssertFalse(MenuBarModel.isSystemFixed(bundleIdentifier: "com.alibaba.DingTalkMac"))
        XCTAssertFalse(MenuBarModel.isSystemFixed(bundleIdentifier: nil))
    }

    func testWiFiIsSystemManaged() {
        let item = MenuBarItemSnapshot(
            id: 1,
            ownerPID: 1,
            ownerName: "控制中心",
            title: "Wi‑Fi，已接入，2格",
            frame: .zero,
            isOnScreen: true
        )
        XCTAssertTrue(item.isSystemManagedWiFi)
    }

    func testUnrecordedItemDefaultsToVisible() {
        let item = MenuBarItemSnapshot(
            id: 1,
            ownerPID: 1,
            ownerName: "New App",
            title: "",
            frame: CGRect(x: -40, y: 0, width: 32, height: 33),
            isOnScreen: false
        )
        let separator = CGRect(x: 0, y: 0, width: 500, height: 33)

        XCTAssertTrue(item.needsRestoring(separatorFrame: separator, hiddenKeys: []))
        XCTAssertFalse(item.needsRestoring(separatorFrame: separator, hiddenKeys: [item.persistenceKey]))
    }

    func testReorderDropsBeforeTargetInsteadOfInsideIt() {
        let target = ControlTarget(id: 1, frame: CGRect(x: 500, y: 0, width: 20, height: 33))

        XCTAssertLessThan(target.insertionXBefore, target.frame.minX)
    }
}
