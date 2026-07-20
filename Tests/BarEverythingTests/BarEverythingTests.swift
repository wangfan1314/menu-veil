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

    func testOnlyUnmovableAppleItemsAreSystemFixed() {
        XCTAssertTrue(MenuBarModel.isSystemFixed(
            bundleIdentifier: "com.apple.controlcenter",
            displayName: "时钟"
        ))
        XCTAssertTrue(MenuBarModel.isSystemFixed(
            bundleIdentifier: "com.apple.controlcenter",
            displayName: "com.apple.menuextra.controlcenter"
        ))
        XCTAssertTrue(MenuBarModel.isSystemFixed(
            bundleIdentifier: "com.apple.controlcenter",
            displayName: "控制中心、录屏正被使用"
        ))
        XCTAssertFalse(MenuBarModel.isSystemFixed(
            bundleIdentifier: "com.apple.controlcenter",
            displayName: "Wi-Fi"
        ))
        XCTAssertFalse(MenuBarModel.isSystemFixed(
            bundleIdentifier: "com.apple.controlcenter",
            displayName: "电池"
        ))
        XCTAssertFalse(MenuBarModel.isSystemFixed(
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            displayName: "Clock"
        ))
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

    func testMenuBarGeometryKeepsOnlyOneDisplaysStatusWindows() {
        let primary = MenuBarGeometry(minY: 0, height: 33)

        XCTAssertTrue(primary.contains(CGRect(x: 1200, y: 0, width: 32, height: 33)))
        XCTAssertTrue(primary.contains(CGRect(x: -3000, y: 0, width: 32, height: 33)))
        XCTAssertFalse(primary.contains(CGRect(x: 3200, y: -498, width: 32, height: 30)))
    }

    func testReplicatedMenuVeilControlsAreExcludedByTitle() {
        XCTAssertTrue(MenuBarModel.isMenuVeilControlTitle("MenuVeil.Toggle"))
        XCTAssertTrue(MenuBarModel.isMenuVeilControlTitle("MenuVeil.Separator"))
        XCTAssertTrue(MenuBarModel.isMenuVeilControlTitle("com.wangzhizhong.MenuVeil"))
        XCTAssertFalse(MenuBarModel.isMenuVeilControlTitle("Bluetooth"))
    }
}
