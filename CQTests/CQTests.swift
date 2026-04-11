//
//  CQTests.swift
//  CQTests
//
//  Created by 烟雀 on 2023/12/6.
//

import XCTest
import AppKit
@testable import CQ

final class CQTests: XCTestCase {
    func testQuitGuardSettingsStoreLoadsDefaults() {
        let userDefaults = makeUserDefaults()
        let store = QuitGuardSettingsStore(userDefaults: userDefaults)
        let settings = store.load()

        XCTAssertEqual(settings.doubleTapInterval, 3)
        XCTAssertEqual(settings.alertWindowCloseTime, 3)
    }

    func testQuitGuardConfigRestoresPersistedSettings() {
        let userDefaults = makeUserDefaults()
        let store = QuitGuardSettingsStore(userDefaults: userDefaults)
        let config = QuitGuardConfig(store: store)

        config.doubleTapInterval = 7
        config.alertWindowCloseTime = 5

        let restored = QuitGuardConfig(
            store: QuitGuardSettingsStore(userDefaults: userDefaults)
        )
        XCTAssertEqual(restored.doubleTapInterval, 7)
        XCTAssertEqual(restored.alertWindowCloseTime, 5)
    }

    func testFirstCommandQRequiresConfirmation() {
        let config = makeConfig()
        let state = QuitGuardState()

        let decision = state.handleCommandQKeyDown(now: 1_000, config: config)

        XCTAssertEqual(decision, .blockAndPrompt(.confirmExit(window: 3)))
        XCTAssertTrue(state.isAwaitingSecondPress)
    }

    func testSecondCommandQPassesWithinWindow() {
        let config = makeConfig()
        let state = QuitGuardState()

        _ = state.handleCommandQKeyDown(now: 1_000, config: config)
        state.markKeyUp()
        let decision = state.handleCommandQKeyDown(now: 2_000, config: config)

        XCTAssertEqual(decision, .passAndReset(nil))
        XCTAssertFalse(state.isAwaitingSecondPress)
    }

    func testTimeoutResetsConfirmation() {
        let config = makeConfig(doubleTap: 0.05)
        let state = QuitGuardState()
        let expectation = expectation(description: "等待确认状态过期")

        _ = state.handleCommandQKeyDown(now: 1_000, config: config)
        state.markKeyUp()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        let decision = state.handleCommandQKeyDown(now: 2_000, config: config)
        XCTAssertEqual(decision, .blockAndPrompt(.confirmExit(window: 0.05)))
    }

    func testLongPressDoesNotBecomeSecondConfirmation() {
        let config = makeConfig()
        let state = QuitGuardState()

        _ = state.handleCommandQKeyDown(now: 1_000, config: config)
        let longPress = state.handleCommandQKeyDown(now: 1_200, config: config)
        state.markKeyUp()
        let nextPress = state.handleCommandQKeyDown(now: 2_000, config: config)

        XCTAssertEqual(longPress, .passAndReset(.ignoredLongPress))
        XCTAssertEqual(nextPress, .blockAndPrompt(.confirmExit(window: 3)))
    }

    func testBlacklistedAppAlwaysPasses() {
        let handler = makeHandler(isBlockedApp: true)
        let decision = handler.decision(
            for: commandQEvent(keyDown: true, flags: [.maskCommand]),
            eventType: .keyDown
        )

        XCTAssertEqual(decision, .pass)
    }

    func testCommandShiftQWillNotBeIntercepted() {
        let handler = makeHandler(isBlockedApp: false)
        let decision = handler.decision(
            for: commandQEvent(keyDown: true, flags: [.maskCommand, .maskShift]),
            eventType: .keyDown
        )

        XCTAssertEqual(decision, .pass)
    }

    func testWakeResetClearsRuntimeState() {
        let handler = makeHandler(isBlockedApp: false)
        let firstDecision = handler.decision(
            for: commandQEvent(keyDown: true, flags: [.maskCommand]),
            eventType: .keyDown
        )

        XCTAssertEqual(firstDecision, .blockAndPrompt(.confirmExit(window: 3)))
        handler.resetRuntimeState()

        let secondDecision = handler.decision(
            for: commandQEvent(keyDown: true, flags: [.maskCommand]),
            eventType: .keyDown
        )

        XCTAssertEqual(secondDecision, .blockAndPrompt(.confirmExit(window: 3)))
    }

    func testConfirmExitPromptCarriesReadableCopyAndProgress() {
        let prompt = QuitPrompt.confirmExit(window: 3)

        XCTAssertEqual(prompt.title, "已拦截 Cmd+Q")
        XCTAssertEqual(prompt.message, "3 秒内再按一次即可退出")
        XCTAssertEqual(prompt.badgeText, "⌘Q")
        XCTAssertTrue(prompt.showsProgress)
    }

    func testIgnoredLongPressPromptUsesSecondaryStyle() {
        let prompt = QuitPrompt.ignoredLongPress

        XCTAssertEqual(prompt.title, "已忽略长按 Cmd+Q")
        XCTAssertEqual(prompt.message, "松开后重新按下，才会计入退出确认")
        XCTAssertNil(prompt.badgeText)
        XCTAssertFalse(prompt.showsProgress)
    }

    /// 验证仅缺辅助功能权限时会返回对应缺失项。
    func testQuitGuardPermissionServiceMarksAccessibilityMissing() {
        let service = QuitGuardPermissionService(
            accessibilityChecker: { _ in false },
            listenEventChecker: { true },
            listenEventRequester: { true }
        )

        let availability = service.currentAvailability(promptAccessibility: false)
        XCTAssertEqual(availability.missingPermissions, [.accessibility])
        XCTAssertFalse(availability.canStartIntercepting)
    }

    /// 验证仅缺事件监听权限时会返回对应缺失项。
    func testQuitGuardPermissionServiceMarksListenEventMissing() {
        let service = QuitGuardPermissionService(
            accessibilityChecker: { _ in true },
            listenEventChecker: { false },
            listenEventRequester: { false }
        )

        let availability = service.currentAvailability(promptAccessibility: false)
        XCTAssertEqual(availability.missingPermissions, [.listenEvent])
        XCTAssertFalse(availability.canStartIntercepting)
    }

    /// 验证两项权限都缺失时会完整返回缺失列表。
    func testQuitGuardPermissionServiceMarksAllPermissionsMissing() {
        let service = QuitGuardPermissionService(
            accessibilityChecker: { _ in false },
            listenEventChecker: { false },
            listenEventRequester: { false }
        )

        let availability = service.currentAvailability(promptAccessibility: false)
        XCTAssertEqual(availability.missingPermissions, [.accessibility, .listenEvent])
        XCTAssertFalse(availability.canStartIntercepting)
    }

    /// 验证两项权限满足时退出保护可以启动。
    func testQuitGuardPermissionServiceMarksAvailabilityReady() {
        let service = QuitGuardPermissionService(
            accessibilityChecker: { _ in true },
            listenEventChecker: { true },
            listenEventRequester: { true }
        )

        let availability = service.currentAvailability(promptAccessibility: false)
        XCTAssertTrue(availability.missingPermissions.isEmpty)
        XCTAssertTrue(availability.canStartIntercepting)
    }

    /// 验证请求事件监听权限成功后会返回最新权限快照。
    func testQuitGuardPermissionServiceUpdatesAvailabilityAfterListenAccessRequest() {
        var hasListenEventAccess = false
        let service = QuitGuardPermissionService(
            accessibilityChecker: { _ in true },
            listenEventChecker: { hasListenEventAccess },
            listenEventRequester: {
                hasListenEventAccess = true
                return true
            }
        )

        let availability = service.requestListenEventAccess()
        XCTAssertTrue(availability.hasListenEventAccess)
        XCTAssertTrue(availability.canStartIntercepting)
    }

    /// 验证事件监听权限请求失败后仍会保留缺失状态。
    func testQuitGuardPermissionServiceKeepsMissingStateWhenListenAccessRequestFails() {
        let service = QuitGuardPermissionService(
            accessibilityChecker: { _ in true },
            listenEventChecker: { false },
            listenEventRequester: { false }
        )

        let availability = service.requestListenEventAccess()
        XCTAssertEqual(availability.missingPermissions, [.listenEvent])
        XCTAssertFalse(availability.canStartIntercepting)
    }

    /// 验证启动编排在权限不足时不会启动 tap。
    @MainActor
    func testAppDelegateLaunchMarksMissingPermissionsWithoutStartingTap() {
        let permissionSpy = PermissionServiceSpy(
            currentAvailability: QuitGuardAvailability(
                isAccessibilityTrusted: false,
                hasListenEventAccess: true
            )
        )
        let runtimeStore = QuitGuardRuntimeStore()
        let tapSpy = TapControllerSpy()
        let delegate = makeAppDelegate(
            permissionService: permissionSpy,
            runtimeStore: runtimeStore,
            tapSpy: tapSpy
        )

        let availability = delegate.readAvailability(promptAccessibility: true)
        delegate.syncQuitGuardStatus(with: availability, refreshTap: false)
        XCTAssertEqual(runtimeStore.status, .missingPermissions([.accessibility]))
        XCTAssertEqual(permissionSpy.promptAccessibilityValues, [true])
        XCTAssertEqual(tapSpy.startCallCount, 0)
        XCTAssertEqual(tapSpy.stopCallCount, 1)
    }

    /// 验证启动编排在 tap 创建失败时会进入失败状态。
    @MainActor
    func testAppDelegateLaunchMarksTapCreateFailedWhenTapStartFails() {
        let permissionSpy = PermissionServiceSpy(
            currentAvailability: QuitGuardAvailability(
                isAccessibilityTrusted: true,
                hasListenEventAccess: true
            )
        )
        let runtimeStore = QuitGuardRuntimeStore()
        let tapSpy = TapControllerSpy(startResult: false)
        let delegate = makeAppDelegate(
            permissionService: permissionSpy,
            runtimeStore: runtimeStore,
            tapSpy: tapSpy
        )

        let availability = delegate.readAvailability(promptAccessibility: true)
        delegate.syncQuitGuardStatus(with: availability, refreshTap: false)
        XCTAssertEqual(runtimeStore.status, .tapCreateFailed)
        XCTAssertEqual(tapSpy.startCallCount, 1)
    }

    /// 验证启动编排在 tap 创建成功时会进入可用状态。
    @MainActor
    func testAppDelegateLaunchMarksReadyWhenTapStarts() {
        let permissionSpy = PermissionServiceSpy(
            currentAvailability: QuitGuardAvailability(
                isAccessibilityTrusted: true,
                hasListenEventAccess: true
            )
        )
        let runtimeStore = QuitGuardRuntimeStore()
        let tapSpy = TapControllerSpy(startResult: true)
        let delegate = makeAppDelegate(
            permissionService: permissionSpy,
            runtimeStore: runtimeStore,
            tapSpy: tapSpy
        )

        let availability = delegate.readAvailability(promptAccessibility: true)
        delegate.syncQuitGuardStatus(with: availability, refreshTap: false)
        XCTAssertEqual(runtimeStore.status, .ready)
        XCTAssertEqual(tapSpy.startCallCount, 1)
    }

    /// 验证唤醒编排在权限丢失时会停止拦截。
    @MainActor
    func testAppDelegateWakeMarksMissingPermissionsAndStopsTap() {
        let permissionSpy = PermissionServiceSpy(
            currentAvailability: QuitGuardAvailability(
                isAccessibilityTrusted: true,
                hasListenEventAccess: false
            )
        )
        let runtimeStore = QuitGuardRuntimeStore(status: .ready)
        let tapSpy = TapControllerSpy()
        let delegate = makeAppDelegate(
            permissionService: permissionSpy,
            runtimeStore: runtimeStore,
            tapSpy: tapSpy
        )

        let availability = delegate.readAvailability(promptAccessibility: false)
        delegate.syncQuitGuardStatus(with: availability, refreshTap: true)
        XCTAssertEqual(runtimeStore.status, .missingPermissions([.listenEvent]))
        XCTAssertEqual(permissionSpy.promptAccessibilityValues, [false])
        XCTAssertEqual(tapSpy.stopCallCount, 1)
    }

    /// 验证唤醒编排在权限满足时会通过 refresh 恢复拦截。
    @MainActor
    func testAppDelegateWakeMarksReadyWhenTapRefreshes() {
        let permissionSpy = PermissionServiceSpy(
            currentAvailability: QuitGuardAvailability(
                isAccessibilityTrusted: true,
                hasListenEventAccess: true
            )
        )
        let runtimeStore = QuitGuardRuntimeStore(status: .tapDisabled)
        let tapSpy = TapControllerSpy(refreshResult: true)
        let delegate = makeAppDelegate(
            permissionService: permissionSpy,
            runtimeStore: runtimeStore,
            tapSpy: tapSpy
        )

        let availability = delegate.readAvailability(promptAccessibility: false)
        delegate.syncQuitGuardStatus(with: availability, refreshTap: true)
        XCTAssertEqual(runtimeStore.status, .ready)
        XCTAssertEqual(tapSpy.refreshCallCount, 1)
    }

    /// 验证 tap 创建失败时会立即回传失败状态。
    func testEventTapControllerStartReportsTapCreateFailure() {
        var statuses: [QuitGuardRuntimeStatus] = []
        let controller = EventTapController(
            config: makeConfig(),
            handler: makeHandler(isBlockedApp: false),
            statusHandler: { statuses.append($0) },
            tapCreator: { _, _, _ in nil }
        )

        XCTAssertFalse(controller.start())
        XCTAssertEqual(statuses, [.tapCreateFailed])
    }

    /// 验证 tap 被系统停用后，恢复成功会回传 ready。
    func testEventTapControllerReportsReadyAfterTapRecovers() {
        var statuses: [QuitGuardRuntimeStatus] = []
        var taps: [CFMachPort?] = [makeTestMachPort(), makeTestMachPort()]
        let controller = EventTapController(
            config: makeConfig(),
            handler: makeHandler(isBlockedApp: false),
            statusHandler: { statuses.append($0) },
            tapCreator: { _, _, _ in taps.removeFirst() }
        )

        XCTAssertTrue(controller.start())
        controller.handleTapDisabled(.tapDisabledByTimeout)
        waitForAsyncWork()
        XCTAssertEqual(statuses, [.tapDisabled, .ready])
    }

    /// 验证 tap 被系统停用后，恢复失败会回传创建失败状态。
    func testEventTapControllerReportsFailureWhenTapRecoveryFails() {
        var statuses: [QuitGuardRuntimeStatus] = []
        var taps: [CFMachPort?] = [makeTestMachPort(), nil]
        let controller = EventTapController(
            config: makeConfig(),
            handler: makeHandler(isBlockedApp: false),
            statusHandler: { statuses.append($0) },
            tapCreator: { _, _, _ in taps.removeFirst() }
        )

        XCTAssertTrue(controller.start())
        controller.handleTapDisabled(.tapDisabledByUserInput)
        waitForAsyncWork()
        XCTAssertEqual(statuses, [.tapDisabled, .tapCreateFailed])
    }

    func testMenuPanelDraftsOnlyWriteAfterApply() {
        let config = makeConfig(doubleTap: 3, alert: 3)
        let model = MenuPanelModel(
            config: config,
            blackList: makeBlackList(),
            isAutoLaunchEnabled: { false },
            setAutoLaunch: { _ in },
            quitAction: {}
        )

        model.doubleTapIntervalDraft = 7
        model.alertCloseTimeDraft = 5

        XCTAssertEqual(config.doubleTapInterval, 3)
        XCTAssertEqual(config.alertWindowCloseTime, 3)

        model.applySettings()

        XCTAssertEqual(config.doubleTapInterval, 7)
        XCTAssertEqual(config.alertWindowCloseTime, 5)
    }

    func testMenuPanelTracksPendingChanges() {
        let config = makeConfig(doubleTap: 2, alert: 4)
        let model = MenuPanelModel(
            config: config,
            blackList: makeBlackList(),
            isAutoLaunchEnabled: { false },
            setAutoLaunch: { _ in },
            quitAction: {}
        )

        XCTAssertFalse(model.hasPendingChanges)
        model.doubleTapIntervalDraft = 6
        XCTAssertTrue(model.hasPendingChanges)
    }

    func testWhitelistStoreReturnsEmptyWhenFileMissing() {
        let store = WhitelistStore(fileURL: makeTempFileURL())
        XCTAssertEqual(store.load(), [])
    }

    func testWhitelistStoreCreatesDirectoryAndRestoresRecords() {
        let fileURL = makeTempFileURL()
        let store = WhitelistStore(fileURL: fileURL)

        store.save(["/Applications/A.app", "/Applications/B.app"])

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: fileURL.deletingLastPathComponent().path)
        )
        XCTAssertEqual(WhitelistStore(fileURL: fileURL).load(), [
            "/Applications/A.app",
            "/Applications/B.app"
        ])
    }

    func testBlackListAppendPersistsWithoutDuplicates() {
        let fileURL = makeTempFileURL()
        let blackList = BlackList(store: WhitelistStore(fileURL: fileURL))

        blackList.append(data: "/Applications/A.app")
        blackList.append(data: "/Applications/A.app")

        XCTAssertEqual(
            BlackList(store: WhitelistStore(fileURL: fileURL)).records,
            ["/Applications/A.app"]
        )
    }

    func testBlackListRemovePersists() {
        let fileURL = makeTempFileURL()
        let blackList = BlackList(store: WhitelistStore(fileURL: fileURL))

        blackList.append(data: "/Applications/A.app")
        blackList.remove(data: "/Applications/A.app")

        XCTAssertEqual(BlackList(store: WhitelistStore(fileURL: fileURL)).records, [])
    }

    func testBlackListContainsUsesIndex() {
        let blackList = makeBlackList(records: ["/Applications/A.app"])

        XCTAssertTrue(blackList.contains("/Applications/A.app"))
        blackList.remove(data: "/Applications/A.app")
        XCTAssertFalse(blackList.contains("/Applications/A.app"))
    }

    func testMenuPanelSearchMatchesAppName() {
        let model = makeMenuPanelModel(records: [
            "/Applications/Safari.app",
            "/Applications/Xcode.app"
        ])

        model.whitelistSearchText = "safari"

        XCTAssertEqual(model.filteredWhitelistItems, ["/Applications/Safari.app"])
    }

    func testMenuPanelSearchMatchesPathCaseInsensitively() {
        let model = makeMenuPanelModel(records: [
            "/System/Applications/Utilities/Terminal.app",
            "/Applications/Xcode.app"
        ])

        model.whitelistSearchText = "utilities/terminal"

        XCTAssertEqual(
            model.filteredWhitelistItems,
            ["/System/Applications/Utilities/Terminal.app"]
        )
    }

    func testMenuPanelSearchClearsHiddenSelection() {
        let terminal = "/System/Applications/Utilities/Terminal.app"
        let model = makeMenuPanelModel(records: [
            terminal,
            "/Applications/Xcode.app"
        ])

        model.selectWhitelistItem(terminal)
        model.whitelistSearchText = "xcode"

        XCTAssertNil(model.selectedWhitelistItem)
    }

    func testInstalledAppCatalogLoadsAppsAcrossDirectoriesAndSortsThem() throws {
        let root = makeTempDirectoryURL()
        let apps = root.appendingPathComponent("Applications", isDirectory: true)
        let homeApps = root.appendingPathComponent("HomeApplications", isDirectory: true)
        let systemApps = root.appendingPathComponent("SystemApplications", isDirectory: true)
        try createDirectories([apps, homeApps, systemApps])
        try createAppBundle(at: apps.appendingPathComponent("Safari.app"))
        try createAppBundle(at: homeApps.appendingPathComponent("Arc.app"))
        try createAppBundle(
            at: systemApps.appendingPathComponent("Utilities/Terminal.app")
        )
        try FileManager.default.createDirectory(
            at: apps.appendingPathComponent("Notes"),
            withIntermediateDirectories: true
        )

        let catalog = InstalledAppCatalog(
            fileManager: .default,
            appDirectories: [apps.path, homeApps.path, systemApps.path, apps.path]
        )

        XCTAssertEqual(
            catalog.loadApps(refresh: true).map(\.path),
            [
                homeApps.appendingPathComponent("Arc.app").path,
                apps.appendingPathComponent("Safari.app").path,
                systemApps.appendingPathComponent("Utilities/Terminal.app").path
            ]
        )
    }

    func testMenuPanelAppPickerLoadsCatalogItems() {
        let item = makeAppPickerItem("/Applications/Safari.app")
        let model = makeMenuPanelModel(
            records: [],
            appCatalog: AppCatalogSpy(items: [item])
        )

        model.addWhitelistApp()
        waitForAsyncWork()

        XCTAssertTrue(model.isShowingAppPicker)
        XCTAssertEqual(model.filteredAppPickerItems, [item])
        XCTAssertFalse(model.isLoadingAppPicker)
    }

    func testMenuPanelAppPickerSearchMatchesAppNameAndPath() {
        let terminal = makeAppPickerItem("/System/Applications/Utilities/Terminal.app")
        let safari = makeAppPickerItem("/Applications/Safari.app")
        let model = makeMenuPanelModel(
            records: [],
            appCatalog: AppCatalogSpy(items: [terminal, safari])
        )

        model.addWhitelistApp()
        waitForAsyncWork()
        model.appPickerSearchText = "utilities/terminal"
        XCTAssertEqual(model.filteredAppPickerItems, [terminal])

        model.appPickerSearchText = "safari"
        XCTAssertEqual(model.filteredAppPickerItems, [safari])
    }

    func testMenuPanelConfirmAppPickerSelectionAppendsWhitelist() {
        let safari = makeAppPickerItem("/Applications/Safari.app")
        let blackList = makeBlackList()
        let model = makeMenuPanelModel(
            records: [],
            blackList: blackList,
            appCatalog: AppCatalogSpy(items: [safari])
        )

        model.addWhitelistApp()
        waitForAsyncWork()
        model.selectAppPickerItem(safari)
        model.confirmAppPickerSelection()

        XCTAssertEqual(blackList.records, [safari.path])
        XCTAssertFalse(model.isShowingAppPicker)
    }

    func testMenuPanelFinderPickerCancellationDoesNotWriteWhitelist() {
        let blackList = makeBlackList()
        let model = makeMenuPanelModel(
            records: [],
            blackList: blackList,
            appCatalog: AppCatalogSpy(items: []),
            systemAppPicker: SystemAppPickerSpy(selectedURL: nil)
        )

        model.addWhitelistApp()
        waitForAsyncWork()
        model.addWhitelistAppFromFinder()
        waitForAsyncWork()

        XCTAssertTrue(blackList.records.isEmpty)
        XCTAssertFalse(model.isShowingAppPicker)
    }

    func testMenuButtonEventMaskSupportsLeftAndRightClick() {
        XCTAssertEqual(menuButtonEventMask, [.leftMouseUp, .rightMouseUp])
    }

    func testMenuPopoverInteractionKeepsStatusButtonClick() {
        let shouldClose = MenuPopoverInteraction.shouldClose(
            at: NSPoint(x: 5, y: 5),
            popoverFrame: NSRect(x: 20, y: 20, width: 100, height: 100),
            buttonFrame: NSRect(x: 0, y: 0, width: 10, height: 10)
        )

        XCTAssertFalse(shouldClose)
    }

    func testMenuPopoverInteractionKeepsPopoverClick() {
        let shouldClose = MenuPopoverInteraction.shouldClose(
            at: NSPoint(x: 50, y: 50),
            popoverFrame: NSRect(x: 20, y: 20, width: 100, height: 100),
            buttonFrame: NSRect(x: 0, y: 0, width: 10, height: 10)
        )

        XCTAssertFalse(shouldClose)
    }

    func testMenuPopoverInteractionClosesOnOutsideClick() {
        let shouldClose = MenuPopoverInteraction.shouldClose(
            at: NSPoint(x: 200, y: 200),
            popoverFrame: NSRect(x: 20, y: 20, width: 100, height: 100),
            buttonFrame: NSRect(x: 0, y: 0, width: 10, height: 10)
        )

        XCTAssertTrue(shouldClose)
    }
}

private extension CQTests {
    func makeConfig(doubleTap: TimeInterval = 3, alert: TimeInterval = 3) -> QuitGuardConfig {
        let store = QuitGuardSettingsStore(userDefaults: makeUserDefaults())
        let config = QuitGuardConfig(store: store)
        config.doubleTapInterval = doubleTap
        config.alertWindowCloseTime = alert
        return config
    }

    func makeBlackList(records: [String] = []) -> BlackList {
        let blackList = BlackList(store: WhitelistStore(fileURL: makeTempFileURL()))
        records.forEach { blackList.append(data: $0) }
        return blackList
    }

    func makeMenuPanelModel(
        records: [String],
        blackList: BlackList? = nil,
        appCatalog: InstalledAppCataloging = AppCatalogSpy(items: []),
        systemAppPicker: SystemAppPicking = SystemAppPickerSpy(selectedURL: nil)
    ) -> MenuPanelModel {
        MenuPanelModel(
            config: makeConfig(),
            blackList: blackList ?? makeBlackList(records: records),
            appCatalog: appCatalog,
            systemAppPicker: systemAppPicker,
            appCatalogQueue: DispatchQueue(label: "CQTests.appCatalogQueue"),
            isAutoLaunchEnabled: { false },
            setAutoLaunch: { _ in },
            quitAction: {}
        )
    }

    func makeUserDefaults() -> UserDefaults {
        let suiteName = "CQTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    func makeTempFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return directory.appendingPathComponent("whitelist.json")
    }

    func makeTempDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    func createDirectories(_ urls: [URL]) throws {
        for url in urls {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    func createAppBundle(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    func makeAppPickerItem(_ path: String) -> AppPickerItem {
        AppPickerItem(url: URL(fileURLWithPath: path))
    }

    func waitForAsyncWork() {
        let expectation = expectation(description: "等待异步处理完成")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func makeHandler(isBlockedApp: Bool) -> EventHandler {
        EventHandler(
            config: makeConfig(),
            state: QuitGuardState(),
            isBlockedApp: { isBlockedApp }
        )
    }

    /// 构造用于编排测试的 AppDelegate，并注入可观察的 tap 控制器。
    /// - Parameters:
    ///   - permissionService: 权限检查桩对象。
    ///   - runtimeStore: 运行状态存储。
    ///   - tapSpy: tap 控制器桩对象。
    /// - Returns: 注入完成的 AppDelegate。
    @MainActor
    func makeAppDelegate(
        permissionService: QuitGuardPermissionChecking,
        runtimeStore: QuitGuardRuntimeStore,
        tapSpy: TapControllerSpy
    ) -> AppDelegate {
        AppDelegate(
            config: makeConfig(),
            state: QuitGuardState(),
            permissionService: permissionService,
            runtimeStore: runtimeStore,
            eventTapControllerFactory: { _, _, _ in tapSpy }
        )
    }

    func commandQEvent(keyDown: Bool, flags: CGEventFlags) -> CGEvent {
        let source = CGEventSource(stateID: .combinedSessionState)
        let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: 12,
            keyDown: keyDown
        )!
        event.flags = flags
        return event
    }

    /// 构造一个可供测试使用的 MachPort，用来模拟成功创建的 event tap。
    /// - Returns: 可被 run loop 持有的 MachPort 实例。
    func makeTestMachPort() -> CFMachPort {
        var context = CFMachPortContext()
        let callback: CFMachPortCallBack = { _, _, _, _ in }
        return CFMachPortCreate(kCFAllocatorDefault, callback, &context, nil)!
    }
}

private struct AppCatalogSpy: InstalledAppCataloging {
    let items: [AppPickerItem]

    func loadApps(refresh: Bool) -> [AppPickerItem] {
        items
    }
}

private struct SystemAppPickerSpy: SystemAppPicking {
    let selectedURL: URL?

    func pickApp() -> URL? {
        selectedURL
    }
}

private final class PermissionServiceSpy: QuitGuardPermissionChecking {
    private let currentValue: QuitGuardAvailability
    private let requestedValue: QuitGuardAvailability
    private(set) var promptAccessibilityValues: [Bool] = []

    init(
        currentAvailability: QuitGuardAvailability,
        requestedAvailability: QuitGuardAvailability? = nil
    ) {
        self.currentValue = currentAvailability
        self.requestedValue = requestedAvailability ?? currentAvailability
    }

    /// 返回预设的权限快照，并记录启动方是否请求过辅助功能提示。
    /// - Parameter promptAccessibility: 是否触发辅助功能提示。
    /// - Returns: 预设的权限快照。
    func currentAvailability(promptAccessibility: Bool) -> QuitGuardAvailability {
        promptAccessibilityValues.append(promptAccessibility)
        return currentValue
    }

    /// 返回预设的事件监听权限请求结果。
    /// - Returns: 请求后的权限快照。
    func requestListenEventAccess() -> QuitGuardAvailability {
        requestedValue
    }
}

private final class TapControllerSpy: QuitGuardControlling {
    private let startResult: Bool
    private let refreshResult: Bool
    private(set) var startCallCount: Int = 0
    private(set) var stopCallCount: Int = 0
    private(set) var refreshCallCount: Int = 0

    init(startResult: Bool = true, refreshResult: Bool = true) {
        self.startResult = startResult
        self.refreshResult = refreshResult
    }

    /// 记录启动调用次数，并返回预设结果。
    /// - Returns: 预设的启动结果。
    func start() -> Bool {
        startCallCount += 1
        return startResult
    }

    /// 记录停止调用次数。
    func stop() {
        stopCallCount += 1
    }

    /// 记录恢复调用次数，并返回预设结果。
    /// - Returns: 预设的恢复结果。
    func refresh() -> Bool {
        refreshCallCount += 1
        return refreshResult
    }
}
