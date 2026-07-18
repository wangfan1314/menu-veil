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

    func testItemsRightOfToggleAreSystemFixed() {
        let toggle = CGRect(x: 1505, y: 0, width: 32, height: 33)
        XCTAssertTrue(MenuBarItemSnapshot.canHide(frame: CGRect(x: 1467, y: 0, width: 38, height: 33), toggleFrame: toggle))
        XCTAssertFalse(MenuBarItemSnapshot.canHide(frame: CGRect(x: 1579, y: 0, width: 151, height: 33), toggleFrame: toggle))
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
}
