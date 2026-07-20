import ApplicationServices
import AppKit
import SwiftUI

struct MenuBarItemSnapshot: Identifiable, Hashable {
    let id: CGWindowID
    let ownerPID: pid_t
    let ownerName: String
    let title: String
    let frame: CGRect
    let isOnScreen: Bool

    var displayName: String {
        title.isEmpty ? ownerName : title
    }

    var detail: String {
        title.isEmpty || title == ownerName ? ownerName : ownerName + " · " + title
    }

    var persistenceKey: String {
        "\(ownerName)\u{1F}\(title)\u{1F}\(Int(frame.width.rounded()))"
    }

    var isSystemManagedWiFi: Bool {
        title.lowercased().filter(\.isLetter).hasPrefix("wifi")
    }

    static func isStatusItem(layer: Int, frame: CGRect) -> Bool {
        layer == Int(CGWindowLevelForKey(.statusWindow)) && frame.height > 0 && frame.height <= 64
    }

    func needsRestoring(separatorFrame: CGRect, hiddenKeys: Set<String>) -> Bool {
        !hiddenKeys.contains(persistenceKey) && frame.maxX <= separatorFrame.minX + 1
    }
}

struct ControlTarget {
    let id: CGWindowID
    let frame: CGRect

    var insertionXBefore: CGFloat { frame.minX - 2 }
}

struct MenuBarGeometry: Equatable {
    let minY: CGFloat
    let height: CGFloat

    func contains(_ frame: CGRect) -> Bool {
        abs(frame.minY - minY) <= 1 && abs(frame.height - height) <= 1
    }
}

@MainActor
final class MenuBarModel: ObservableObject {
    static let shared = MenuBarModel()

    @Published private(set) var items: [MenuBarItemSnapshot] = []
    @Published private(set) var isMoving = false
    @Published private(set) var hasAccessibilityPermission = AXIsProcessTrusted()
    @Published var message: String?
    weak var statusBarController: StatusBarController?
    private var excludedItemIDs = Set<CGWindowID>()
    private var preferredMenuBarGeometry: MenuBarGeometry?

    var visibleCount: Int { items.count(where: \.isOnScreen) }
    var hiddenCount: Int { items.count - visibleCount }
    init() {
        refresh()
    }

    func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func refresh() {
        hasAccessibilityPermission = AXIsProcessTrusted()
        let rawWindows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[CFString: Any]] ?? []
        var snapshots = rawWindows.compactMap(Self.snapshot).filter { !excludedItemIDs.contains($0.id) }
        if let preferredMenuBarGeometry {
            snapshots = snapshots.filter { preferredMenuBarGeometry.contains($0.frame) }
        }
        if hasAccessibilityPermission {
            snapshots = Self.attachSourceApplications(to: snapshots)
        }
        items = snapshots.sorted { lhs, rhs in
            if lhs.isOnScreen != rhs.isOnScreen { return lhs.isOnScreen }
            return lhs.frame.minX < rhs.frame.minX
        }
        message = nil
    }

    func excludeControls(_ ids: Set<CGWindowID>) {
        excludedItemIDs = ids
        refresh()
    }

    func preferMenuBar(containing controlFrame: CGRect) {
        preferredMenuBarGeometry = MenuBarGeometry(
            minY: controlFrame.minY,
            height: controlFrame.height
        )
        refresh()
    }

    func canToggle(_ item: MenuBarItemSnapshot) -> Bool {
        !item.isOnScreen || !isSystemFixed(item)
    }

    func canReorder(_ item: MenuBarItemSnapshot) -> Bool {
        !isSystemFixed(item)
    }

    private func isSystemFixed(_ item: MenuBarItemSnapshot) -> Bool {
        let bundleIdentifier = NSRunningApplication(processIdentifier: item.ownerPID)?.bundleIdentifier
        return Self.isSystemFixed(bundleIdentifier: bundleIdentifier, displayName: item.displayName)
    }

    nonisolated static func isSystemFixed(bundleIdentifier: String?, displayName: String) -> Bool {
        guard bundleIdentifier?.hasPrefix("com.apple.") == true else { return false }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["时钟", "clock", "com.apple.menuextra.clock", "控制中心", "control center",
                "com.apple.menuextra.controlcenter"].contains(name)
            || name.hasPrefix("控制中心、")
            || name.hasPrefix("control center,")
    }

    func storedHiddenKeys() -> Set<String>? {
        if let values = UserDefaults.standard.stringArray(forKey: "MenuVeil.HiddenKeys") {
            return Set(values)
        }
        guard let legacy = UserDefaults(suiteName: "com.wangzhizhong.BarEverything")?
            .stringArray(forKey: "BarEverything.HiddenKeys") else { return nil }
        saveHiddenKeys(Set(legacy))
        return Set(legacy)
    }

    func saveHiddenKeys(_ keys: Set<String>) {
        UserDefaults.standard.set(keys.sorted(), forKey: "MenuVeil.HiddenKeys")
    }

    private func setPersistentlyHidden(_ item: MenuBarItemSnapshot, hidden: Bool) {
        var keys = storedHiddenKeys() ?? []
        if hidden {
            keys.insert(item.persistenceKey)
        } else {
            keys.remove(item.persistenceKey)
        }
        saveHiddenKeys(keys)
    }

    func setVisible(_ shouldShow: Bool, item: MenuBarItemSnapshot) async {
        guard hasAccessibilityPermission else {
            message = "请先授予辅助功能权限，然后再试。"
            requestAccessibilityPermission()
            return
        }

        isMoving = true
        defer { isMoving = false }

        do {
            statusBarController?.expandForMove()
            try await Task.sleep(for: .milliseconds(70))
            refresh()

            let currentItem = items.first(where: { $0.id == item.id }) ?? item
            let fallbackItems = items.filter { $0.id != item.id && $0.frame.height <= 64 }
            let fallback = shouldShow
                ? fallbackItems.max(by: { $0.frame.maxX < $1.frame.maxX }).map { ControlTarget(id: $0.id, frame: $0.frame) }
                : fallbackItems.min(by: { $0.frame.minX < $1.frame.minX }).map { ControlTarget(id: $0.id, frame: $0.frame) }
            guard let target = statusBarController?.target(forShowing: shouldShow) ?? fallback else {
                throw MoveError("没有找到可用的目标位置。")
            }

            try await move(currentItem, toward: target, destinationX: target.insertionXBefore)
            try await Task.sleep(for: .milliseconds(180))
            statusBarController?.collapse()
            try await Task.sleep(for: .milliseconds(300))
            refresh()
            let updatedItem = items.first { $0.id == item.id }
                ?? items.first { $0.persistenceKey == item.persistenceKey }
            guard updatedItem?.isOnScreen == shouldShow else {
                throw MoveError("移动没有生效，请再试一次。")
            }
            setPersistentlyHidden(item, hidden: !shouldShow)
        } catch {
            statusBarController?.collapse()
            message = error.localizedDescription
        }
    }

    func reorder(_ item: MenuBarItemSnapshot, before nextItem: MenuBarItemSnapshot?) async {
        guard hasAccessibilityPermission else {
            message = "请先授予辅助功能权限，然后再试。"
            requestAccessibilityPermission()
            return
        }
        guard canReorder(item) else {
            message = "“\(item.displayName)”由系统固定，无法调整顺序。"
            return
        }

        isMoving = true
        defer { isMoving = false }

        do {
            statusBarController?.expandForMove()
            try await Task.sleep(for: .milliseconds(70))
            refresh()

            let currentItem = items.first { $0.id == item.id }
                ?? items.first { $0.persistenceKey == item.persistenceKey }
                ?? item
            let target: ControlTarget
            if let nextItem {
                guard let currentNext = items.first(where: { $0.id == nextItem.id })
                    ?? items.first(where: { $0.persistenceKey == nextItem.persistenceKey }) else {
                    throw MoveError("目标图标已经消失，请刷新后重试。")
                }
                target = ControlTarget(id: currentNext.id, frame: currentNext.frame)
            } else if let sectionEnd = statusBarController?.target(forShowing: item.isOnScreen) {
                target = sectionEnd
            } else {
                throw MoveError("没有找到该分区的末尾位置。")
            }

            try await move(currentItem, toward: target, destinationX: target.insertionXBefore)
            try await Task.sleep(for: .milliseconds(180))
            statusBarController?.collapse()
            try await Task.sleep(for: .milliseconds(220))
            refresh()

            if let nextItem,
               let moved = items.first(where: { $0.id == item.id })
                    ?? items.first(where: { $0.persistenceKey == item.persistenceKey }),
               let next = items.first(where: { $0.id == nextItem.id })
                    ?? items.first(where: { $0.persistenceKey == nextItem.persistenceKey }),
               moved.frame.minX >= next.frame.minX {
                throw MoveError("顺序调整没有生效，请再试一次。")
            }
        } catch {
            statusBarController?.collapse()
            message = error.localizedDescription
        }
    }

    private static func snapshot(_ dictionary: [CFString: Any]) -> MenuBarItemSnapshot? {
        guard
            let id = dictionary[kCGWindowNumber] as? CGWindowID,
            let layer = dictionary[kCGWindowLayer] as? Int,
            let bounds = dictionary[kCGWindowBounds] as? NSDictionary,
            let frame = CGRect(dictionaryRepresentation: bounds),
            let ownerPID = dictionary[kCGWindowOwnerPID] as? pid_t,
            ownerPID != getpid(),
            !isMenuVeilControlTitle(dictionary[kCGWindowName] as? String ?? ""),
            MenuBarItemSnapshot.isStatusItem(layer: layer, frame: frame)
        else {
            return nil
        }

        return MenuBarItemSnapshot(
            id: id,
            ownerPID: ownerPID,
            ownerName: dictionary[kCGWindowOwnerName] as? String ?? "未知应用",
            title: dictionary[kCGWindowName] as? String ?? "",
            frame: frame,
            isOnScreen: dictionary[kCGWindowIsOnscreen] as? Bool ?? false
        )
    }

    nonisolated static func isMenuVeilControlTitle(_ title: String) -> Bool {
        ["MenuVeil.Toggle", "MenuVeil.Separator", "com.wangzhizhong.MenuVeil"].contains(title)
    }

    private static func attachSourceApplications(
        to snapshots: [MenuBarItemSnapshot]
    ) -> [MenuBarItemSnapshot] {
        var sourceItems = [CGWindowID: (app: NSRunningApplication, label: String?)]()
        let candidates = NSWorkspace.shared.runningApplications.filter {
            $0.isFinishedLaunching && !$0.isTerminated && $0.activationPolicy != .prohibited
        }

        for app in candidates {
            let application = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(application, 0.15)

            guard
                let menuBarValue = copyAttribute("AXExtrasMenuBar", from: application),
                CFGetTypeID(menuBarValue) == AXUIElementGetTypeID()
            else { continue }
            let menuBar = unsafeDowncast(menuBarValue, to: AXUIElement.self)
            guard let children = copyAttribute("AXChildren", from: menuBar) as? [AXUIElement] else {
                continue
            }

            for child in children {
                guard
                    (copyAttribute("AXEnabled", from: child) as? Bool) != false,
                    let rawFrameValue = copyAttribute("AXFrame", from: child),
                    CFGetTypeID(rawFrameValue) == AXValueGetTypeID()
                else { continue }
                let frameValue = unsafeDowncast(rawFrameValue, to: AXValue.self)

                var childFrame = CGRect.zero
                guard AXValueGetValue(frameValue, .cgRect, &childFrame) else { continue }

                if let match = snapshots.first(where: {
                    hypot($0.frame.midX - childFrame.midX, $0.frame.midY - childFrame.midY) <= 1
                }) {
                    let label = ["AXDescription", "AXTitle", "AXIdentifier"]
                        .compactMap { copyAttribute($0, from: child) as? String }
                        .first { !$0.isEmpty && $0 != app.localizedName }
                    sourceItems[match.id] = (app, label)
                }
            }
        }

        return snapshots.map { item in
            guard let source = sourceItems[item.id] else { return item }
            let app = source.app
            let useSystemLabel = ["com.apple.controlcenter", "com.apple.systemuiserver"]
                .contains(app.bundleIdentifier)
            return MenuBarItemSnapshot(
                id: item.id,
                ownerPID: app.processIdentifier,
                ownerName: app.localizedName ?? app.bundleIdentifier ?? item.ownerName,
                title: item.title.isEmpty && useSystemLabel ? source.label ?? "" : item.title,
                frame: item.frame,
                isOnScreen: item.isOnScreen
            )
        }
    }

    private static func copyAttribute(_ name: String, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private func move(
        _ item: MenuBarItemSnapshot,
        toward target: ControlTarget,
        destinationX: CGFloat
    ) async throws {
        if item.isOnScreen {
            try await physicallyMove(item, to: CGPoint(x: destinationX, y: target.frame.midY))
            return
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw MoveError("无法创建输入事件。")
        }

        let originalCursor = CGEvent(source: nil)?.location
        CGDisplayHideCursor(CGMainDisplayID())
        defer {
            if let originalCursor { CGWarpMouseCursorPosition(originalCursor) }
            CGDisplayShowCursor(CGMainDisplayID())
        }

        let start = CGPoint(x: 20_000, y: 20_000)
        let end = CGPoint(x: destinationX, y: target.frame.midY)
        guard
            let down = makeMouseEvent(
                source: source,
                type: .leftMouseDown,
                location: start,
                windowID: item.id,
                targetPID: item.ownerPID,
                commandDown: true
            ),
            let up = makeMouseEvent(
                source: source,
                type: .leftMouseUp,
                location: end,
                windowID: target.id,
                targetPID: item.ownerPID,
                commandDown: false
            )
        else {
            throw MoveError("无法创建拖动事件。")
        }

        post(down, to: item.ownerPID)
        try await Task.sleep(for: .milliseconds(70))
        post(up, to: item.ownerPID)
    }

    func moveControl(_ control: ControlTarget, toward target: ControlTarget) async throws {
        let item = MenuBarItemSnapshot(
            id: control.id,
            ownerPID: getpid(),
            ownerName: "MenuVeil",
            title: "",
            frame: control.frame,
            isOnScreen: false
        )
        try await move(item, toward: target, destinationX: target.frame.minX)
    }

    func moveForLayout(_ item: MenuBarItemSnapshot, toward target: ControlTarget) async throws {
        try await move(item, toward: target, destinationX: target.frame.midX)
    }

    private func physicallyMove(_ item: MenuBarItemSnapshot, to requestedEnd: CGPoint) async throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw MoveError("无法创建输入事件。")
        }

        let start = CGPoint(x: item.frame.midX, y: item.frame.midY)
        let end = CGPoint(x: requestedEnd.x, y: start.y)
        let originalCursor = CGEvent(source: nil)?.location
        CGDisplayHideCursor(CGMainDisplayID())
        defer {
            if let originalCursor { CGWarpMouseCursorPosition(originalCursor) }
            CGDisplayShowCursor(CGMainDisplayID())
        }

        CGWarpMouseCursorPosition(start)
        try await Task.sleep(for: .milliseconds(80))

        guard let down = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: start,
            mouseButton: .left
        ) else { throw MoveError("无法创建拖动事件。") }
        down.flags = .maskCommand
        down.post(tap: .cghidEventTap)

        for step in 1...12 {
            let progress = CGFloat(step) / 12
            let point = CGPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            )
            guard let drag = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseDragged,
                mouseCursorPosition: point,
                mouseButton: .left
            ) else { continue }
            drag.flags = .maskCommand
            drag.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(15))
        }

        guard let up = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: end,
            mouseButton: .left
        ) else { throw MoveError("无法结束拖动事件。") }
        up.flags = .maskCommand
        up.post(tap: .cghidEventTap)
    }

    private func makeMouseEvent(
        source: CGEventSource,
        type: CGEventType,
        location: CGPoint,
        windowID: CGWindowID,
        targetPID: pid_t,
        commandDown: Bool
    ) -> CGEvent? {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: location,
            mouseButton: .left
        ) else { return nil }

        if commandDown { event.flags = .maskCommand }
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(targetPID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(windowID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(windowID))
        event.setIntegerValueField(CGEventField(rawValue: 0x33)!, value: Int64(windowID))
        return event
    }

    private func post(_ event: CGEvent, to pid: pid_t) {
        event.postToPid(pid)
        event.post(tap: .cgSessionEventTap)
        event.postToPid(pid)
    }
}

private struct MoveError: LocalizedError {
    let errorDescription: String?

    init(_ message: String) {
        errorDescription = message
    }
}

@MainActor
final class StatusBarController: NSObject {
    private let toggleItem: NSStatusItem
    private let separatorItem: NSStatusItem
    private let popover = NSPopover()
    private var outsideClickMonitor: Any?
    private var screenChangeObserver: Any?
    private weak var model: MenuBarModel?
    private var activeMenuBarGeometry: MenuBarGeometry?

    private var collapsedLength: CGFloat {
        let width = NSScreen.screens.map { $0.frame.width }.max() ?? 1728
        return max(500, min(width * 2, 10_000))
    }

    init(model: MenuBarModel) {
        let togglePositionKey = "NSStatusItem Preferred Position MenuVeil.Toggle"
        let separatorPositionKey = "NSStatusItem Preferred Position MenuVeil.Separator"
        if UserDefaults.standard.object(forKey: togglePositionKey) == nil {
            UserDefaults.standard.set(0, forKey: togglePositionKey)
        }
        if UserDefaults.standard.object(forKey: separatorPositionKey) == nil {
            UserDefaults.standard.set(1, forKey: separatorPositionKey)
        }
        self.toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.separatorItem = NSStatusBar.system.statusItem(withLength: 20)
        self.model = model
        super.init()

        toggleItem.autosaveName = "MenuVeil.Toggle"
        separatorItem.autosaveName = "MenuVeil.Separator"
        separatorItem.length = collapsedLength
        toggleItem.isVisible = true
        separatorItem.isVisible = true

        if let button = toggleItem.button {
            button.image = NSImage(systemSymbolName: "chevron.left.2", accessibilityDescription: "显示隐藏的菜单栏图标")
            button.target = self
            button.action = #selector(togglePopover)
        }
        separatorItem.button?.title = "│"

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: HiddenItemsPopover(
            model: model,
            openSettings: { [weak self] in self?.openSettings() },
            quit: { NSApp.terminate(nil) }
        ))
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            DispatchQueue.main.async {
                self?.popover.performClose(nil)
            }
        }
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                await self?.prepareControls()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            Task { await self?.prepareControls() }
        }
    }

    func expandForMove() {
        separatorItem.length = 20
    }

    func collapse() {
        separatorItem.length = collapsedLength
    }

    func target(forShowing shouldShow: Bool) -> ControlTarget? {
        controlTarget(for: shouldShow ? toggleItem : separatorItem)
    }

    private func prepareControls() async {
        guard let model else { return }
        try? await Task.sleep(for: .milliseconds(70))
        let pointerDisplay = displayBoundsUnderPointer()
        activeMenuBarGeometry = nil
        if let toggle = controlTarget(for: toggleItem, in: pointerDisplay) {
            activeMenuBarGeometry = MenuBarGeometry(
                minY: toggle.frame.minY,
                height: toggle.frame.height
            )
            model.preferMenuBar(containing: toggle.frame)
        }
        model.refresh()

        guard
            let toggle = controlTarget(for: toggleItem),
            let separator = controlTarget(for: separatorItem)
        else {
            collapse()
            return
        }
        model.preferMenuBar(containing: toggle.frame)
        guard let firstVisible = model.items.filter(\.isOnScreen)
            .min(by: { $0.frame.minX < $1.frame.minX }) else {
            collapse()
            return
        }
        model.excludeControls([toggle.id, separator.id])

        let anchor = ControlTarget(id: firstVisible.id, frame: firstVisible.frame)
        let screenMidX = NSScreen.main?.frame.midX ?? 864
        let controlsNeedMoving = toggle.frame.minX < screenMidX || separator.frame.minX > toggle.frame.minX
        let storedHiddenKeys = model.storedHiddenKeys()
        let hiddenKeys = storedHiddenKeys ?? []
        if storedHiddenKeys == nil {
            model.saveHiddenKeys(hiddenKeys)
        }
        let itemsNeedingMove = model.items.filter {
            !$0.isSystemManagedWiFi
                && $0.needsRestoring(separatorFrame: separator.frame, hiddenKeys: hiddenKeys)
        }

        if !controlsNeedMoving && itemsNeedingMove.isEmpty {
            model.refresh()
            return
        }

        expandForMove()
        try? await Task.sleep(for: .milliseconds(70))
        model.refresh()

        if controlsNeedMoving {
            try? await model.moveControl(toggle, toward: anchor)
            try? await Task.sleep(for: .milliseconds(100))
            if
                let latestToggle = controlTarget(for: toggleItem),
                let latestSeparator = controlTarget(for: separatorItem)
            {
                try? await model.moveControl(latestSeparator, toward: latestToggle)
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        model.refresh()
        var failedItems: [String] = []
        if let currentSeparator = controlTarget(for: separatorItem) {
            let itemsToKeepVisible = model.items.filter {
                !$0.isSystemManagedWiFi
                    && $0.needsRestoring(separatorFrame: currentSeparator.frame, hiddenKeys: hiddenKeys)
            }
            for original in itemsToKeepVisible {
                var movedIntoVisibleSection = false
                for _ in 0..<3 {
                    model.refresh()
                    guard
                        let current = model.items.first(where: { $0.id == original.id }),
                        let latestToggle = controlTarget(for: toggleItem)
                    else { break }
                    try? await model.moveForLayout(current, toward: latestToggle)
                    try? await Task.sleep(for: .milliseconds(250))
                    model.refresh()
                    guard
                        let moved = model.items.first(where: { $0.id == original.id }),
                        let movedSeparator = controlTarget(for: separatorItem),
                        let movedToggle = controlTarget(for: toggleItem)
                    else { continue }
                    movedIntoVisibleSection = moved.frame.minX >= movedSeparator.frame.maxX - 1
                        && moved.frame.maxX <= movedToggle.frame.minX + 1
                    if movedIntoVisibleSection { break }
                }
                guard movedIntoVisibleSection else {
                    failedItems.append(original.displayName)
                    continue
                }
            }
        } else {
            expandForMove()
            model.message = "菜单栏分区恢复失败，已保持展开。"
            return
        }

        collapse()
        try? await Task.sleep(for: .milliseconds(200))
        model.refresh()
        if !failedItems.isEmpty {
            model.message = "无法移动“\(failedItems.joined(separator: "、"))”，已留在隐藏区。"
        }
    }

    private func controlTarget(
        for item: NSStatusItem,
        in displayBounds: CGRect? = nil
    ) -> ControlTarget? {
        let title = item === toggleItem ? "MenuVeil.Toggle" : "MenuVeil.Separator"
        guard let descriptions = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[CFString: Any]] else {
            return nil
        }
        let replicaTitle = "com.wangzhizhong.MenuVeil"
        let expectedWidth = item === toggleItem
            ? item.button?.window?.frame.width ?? 32
            : item.length
        let statusWindows = descriptions.filter { dictionary in
            guard
                (dictionary[kCGWindowLayer] as? Int) == Int(CGWindowLevelForKey(.statusWindow)),
                let bounds = dictionary[kCGWindowBounds] as? NSDictionary,
                let frame = CGRect(dictionaryRepresentation: bounds)
            else { return false }
            if let displayBounds, !frame.intersects(displayBounds) { return false }
            if let activeMenuBarGeometry, !activeMenuBarGeometry.contains(frame) { return false }
            return true
        }
        let titledWindow = statusWindows
            .filter {
                let windowTitle = $0[kCGWindowName] as? String ?? ""
                return windowTitle == title || windowTitle == replicaTitle
            }
            .min { lhs, rhs in
                func widthDistance(_ dictionary: [CFString: Any]) -> CGFloat {
                    guard
                        let bounds = dictionary[kCGWindowBounds] as? NSDictionary,
                        let frame = CGRect(dictionaryRepresentation: bounds)
                    else { return .greatestFiniteMagnitude }
                    return abs(frame.width - expectedWidth)
                }
                return widthDistance(lhs) < widthDistance(rhs)
            }
        let geometryWindow: [CFString: Any]? = item.button?.window.flatMap { statusWindow in
            let expectedX = statusWindow.frame.minX
            let expectedWidth = statusWindow.frame.width
            return statusWindows
                .min { lhs, rhs in
                    func distance(_ dictionary: [CFString: Any]) -> CGFloat {
                        guard
                            let bounds = dictionary[kCGWindowBounds] as? NSDictionary,
                            let frame = CGRect(dictionaryRepresentation: bounds)
                        else { return .greatestFiniteMagnitude }
                        return abs(frame.minX - expectedX) + abs(frame.width - expectedWidth)
                    }
                    return distance(lhs) < distance(rhs)
                }
        }
        guard
            let window = titledWindow ?? geometryWindow,
            let id = window[kCGWindowNumber] as? CGWindowID,
            let bounds = window[kCGWindowBounds] as? NSDictionary,
            let frame = CGRect(dictionaryRepresentation: bounds)
        else { return nil }
        return ControlTarget(id: id, frame: frame)
    }

    @objc private func togglePopover() {
        guard let button = toggleItem.button else { return }
        activateMenuBarUnderPointer()
        if popover.isShown {
            popover.performClose(nil)
        } else {
            model?.refresh()
            let count = model?.hiddenCount ?? 0
            popover.contentSize = NSSize(width: 330, height: min(480, CGFloat(120 + count * 48)))
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(120))
                guard let self, self.popover.isShown else { return }
                self.model?.refresh()
                let refreshedCount = self.model?.hiddenCount ?? 0
                self.popover.contentSize = NSSize(
                    width: 330,
                    height: min(480, CGFloat(120 + refreshedCount * 48))
                )
            }
        }
    }

    private func activateMenuBarUnderPointer() {
        guard
            let model,
            let displayBounds = displayBoundsUnderPointer()
        else { return }
        // Clear the previous geometry before looking for another display's replica.
        activeMenuBarGeometry = nil
        guard let toggle = controlTarget(for: toggleItem, in: displayBounds) else { return }
        activeMenuBarGeometry = MenuBarGeometry(
            minY: toggle.frame.minY,
            height: toggle.frame.height
        )
        model.preferMenuBar(containing: toggle.frame)
    }

    private func displayBoundsUnderPointer() -> CGRect? {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) else {
            return nil
        }
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        return CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
    }

    private func openSettings() {
        popover.performClose(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.title == "MenuVeil" }?.makeKeyAndOrderFront(nil)
    }
}

private struct HiddenItemsPopover: View {
    @ObservedObject var model: MenuBarModel
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("已隐藏的图标")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            if model.items.filter({ !$0.isOnScreen }).isEmpty {
                Text("暂无隐藏项目")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(model.items.filter { !$0.isOnScreen }) { item in
                            HStack {
                                let image = NSRunningApplication(processIdentifier: item.ownerPID)?.icon
                                    ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                Text(item.displayName).lineLimit(1)
                                Spacer()
                                Button("显示") {
                                    Task { await model.setVisible(true, item: item) }
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 5)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button("设置", action: openSettings)
                Spacer()
                Button("退出程序", role: .destructive, action: quit)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = StatusBarController(model: .shared)
        statusBarController = controller
        MenuBarModel.shared.statusBarController = controller
        DispatchQueue.main.async { [weak self] in
            NSApp.windows.first { $0.title == "MenuVeil" }?.delegate = self
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        return false
    }
}

struct ContentView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case visible = "显示"
        case hidden = "隐藏"

        var id: Self { self }
    }

    @StateObject private var model = MenuBarModel.shared
    @State private var selectedTab = Tab.visible

    private var filteredItems: [MenuBarItemSnapshot] {
        model.items.filter { $0.isOnScreen == (selectedTab == .visible) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !model.hasAccessibilityPermission {
                Text("辅助功能权限尚未被当前 App 签名识别；macOS 26 暂时只能把项目标记为“控制中心”。")
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            Picker("状态", selection: $selectedTab) {
                Text("显示（\(model.visibleCount)）").tag(Tab.visible)
                Text("隐藏（\(model.hiddenCount)）").tag(Tab.hidden)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)

            List {
                ForEach(filteredItems) { item in
                    ItemRow(
                        item: item,
                        isMoving: model.isMoving,
                        canToggle: model.canToggle(item),
                        canReorder: model.canReorder(item)
                    ) {
                        Task { await model.setVisible(!item.isOnScreen, item: item) }
                    }
                    .moveDisabled(!model.canReorder(item))
                }
                .onMove(perform: moveItems)
            }
            .listStyle(.inset)

            if let message = model.message {
                Text(message)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(minWidth: 680, minHeight: 520)
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        guard source.count == 1, let sourceIndex = source.first else { return }
        let currentItems = filteredItems
        let item = currentItems[sourceIndex]
        guard model.canReorder(item) else { return }

        var reorderedItems = currentItems
        reorderedItems.move(fromOffsets: source, toOffset: destination)
        guard let newIndex = reorderedItems.firstIndex(of: item) else { return }
        let nextItem = reorderedItems.indices.contains(newIndex + 1) ? reorderedItems[newIndex + 1] : nil
        Task { await model.reorder(item, before: nextItem) }
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MenuVeil")
                    .font(.title2.bold())
                Text("共 \(model.items.count) 个 · 可见 \(model.visibleCount) · 不可见 \(model.hiddenCount)")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !model.hasAccessibilityPermission {
                Button("授予辅助功能权限") {
                    model.requestAccessibilityPermission()
                }
            }
            Button("刷新") {
                model.refresh()
            }
            .keyboardShortcut("r")
        }
        .padding()
    }
}

private struct ItemRow: View {
    let item: MenuBarItemSnapshot
    let isMoving: Bool
    let canToggle: Bool
    let canReorder: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(canReorder ? .secondary : .tertiary)
                .help(canReorder ? "拖动调整菜单栏顺序" : "该项目由系统固定")
            appIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(canToggle ? (item.isOnScreen ? "可见" : "不可见") : "系统固定")
                .font(.caption)
                .foregroundStyle(canToggle && item.isOnScreen ? .green : .secondary)
            Button(item.isOnScreen ? "隐藏" : "显示", action: action)
                .disabled(isMoving || !canToggle)
                .frame(width: 54)
        }
        .padding(.vertical, 4)
    }

    private var appIcon: some View {
        let image = NSRunningApplication(processIdentifier: item.ownerPID)?.icon
            ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)!
        return Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 26, height: 26)
    }
}

@main
struct BarEverythingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentMinSize)
    }
}
