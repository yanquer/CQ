//
//  CQTests.swift
//  CQTests
//
//  Created by 烟雀 on 2023/12/6.
//

import XCTest
import AppKit
import Combine
import ServiceManagement
@testable import CQ

final class CQTests: XCTestCase {
    /// 验证新实例启动失败时不会退出仍可工作的当前应用。
    @MainActor
    func testRelaunchFailureKeepsCurrentProcessRunning() {
        var didTerminate = false
        var didReportFailure = false
        let relauncher = AppRelauncher()
        relauncher.restart(
            launch: { $0(NSError(domain: "CQTests.Relaunch", code: 1)) },
            terminate: { didTerminate = true },
            reportFailure: { _ in didReportFailure = true }
        )
        XCTAssertFalse(didTerminate)
        XCTAssertTrue(didReportFailure)
    }

    /// 验证必须收到新实例启动成功回调后才退出，而不是发出启动请求就退出。
    @MainActor
    func testRelaunchWaitsForNewInstanceBeforeTermination() {
        var completion: AppRelauncher.Completion?
        var didTerminate = false
        let relauncher = AppRelauncher()
        relauncher.restart(
            launch: { completion = $0 },
            terminate: { didTerminate = true },
            reportFailure: { _ in XCTFail("Unexpected relaunch failure") }
        )
        XCTAssertFalse(didTerminate)
        completion?(nil)
        XCTAssertTrue(didTerminate)
        XCTAssertTrue(AppRelauncher.makeLaunchConfiguration().createsNewApplicationInstance)
        XCTAssertFalse(AppRelauncher.makeLaunchConfiguration().activates)
    }

    /// 验证启动尚未完成时的重复点击只会请求一个新实例，成功后继续阻止重复请求。
    @MainActor
    func testConcurrentRelaunchRequestsStartOnlyOneInstance() {
        let relauncher = AppRelauncher()
        var launchCount = 0
        var completion: AppRelauncher.Completion?
        let launch: AppRelauncher.Launcher = { callback in
            launchCount += 1
            completion = callback
        }
        relauncher.restart(launch: launch, terminate: {}, reportFailure: { _ in })
        relauncher.restart(launch: launch, terminate: {}, reportFailure: { _ in })
        XCTAssertEqual(launchCount, 1)
        XCTAssertTrue(relauncher.isRestarting)
        completion?(nil)
        relauncher.restart(launch: launch, terminate: {}, reportFailure: { _ in })
        XCTAssertEqual(launchCount, 1)
    }

    /// 验证启动失败会解除重启锁，用户可以再次尝试。
    @MainActor
    func testFailedRelaunchCanBeRetried() {
        let relauncher = AppRelauncher()
        var launchCount = 0
        let launch: AppRelauncher.Launcher = { callback in
            launchCount += 1
            callback(NSError(domain: "CQTests.Relaunch", code: 1))
        }
        relauncher.restart(launch: launch, terminate: {}, reportFailure: { _ in })
        XCTAssertFalse(relauncher.isRestarting)
        relauncher.restart(launch: launch, terminate: {}, reportFailure: { _ in })
        XCTAssertEqual(launchCount, 2)
    }

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

    /// 验证异常偏好类型与非有限数值回退默认值，有限数值限制在支持范围内。
    func testSettingsLoadRejectsInvalidTypesAndNormalizesNumbers() {
        let defaults = makeUserDefaults()
        let store = QuitGuardSettingsStore(userDefaults: defaults)
        let cases: [(Any, TimeInterval)] = [
            ("invalid", 3), ("5", 3), (true, 3), ([1, 2], 3),
            (-5.0, 1), (0.0, 1), (99.0, 8), (2.6, 3),
            (Double.infinity, 3), (-Double.infinity, 3), (Double.nan, 3)
        ]
        for (value, expected) in cases {
            defaults.set(value, forKey: "quit_guard.double_tap_interval")
            defaults.set(value, forKey: "quit_guard.alert_window_close_time")
            let settings = store.load()
            XCTAssertEqual(settings.doubleTapInterval, expected)
            XCTAssertEqual(settings.alertWindowCloseTime, expected)
        }
    }

    /// 验证运行时赋值及直接保存均使用同一规则，不会让非法时长进入事件处理。
    func testConfigAndStoreWritesNormalizeIntervals() {
        let store = QuitGuardSettingsStore(userDefaults: makeUserDefaults())
        let config = QuitGuardConfig(store: store)
        config.doubleTapInterval = .nan
        config.alertWindowCloseTime = 0
        XCTAssertEqual(config.doubleTapInterval, 3)
        XCTAssertEqual(config.alertWindowCloseTime, 1)
        XCTAssertEqual(store.load().alertWindowCloseTime, 1)
        store.save(QuitGuardSettings(doubleTapInterval: 100, alertWindowCloseTime: .infinity))
        XCTAssertEqual(store.load().doubleTapInterval, 8)
        XCTAssertEqual(store.load().alertWindowCloseTime, 3)
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
        let config = makeConfig(doubleTap: 1)
        let state = QuitGuardState()
        let expectation = expectation(description: "等待确认状态过期")

        _ = state.handleCommandQKeyDown(now: 1_000, config: config)
        state.markKeyUp()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        XCTAssertFalse(state.isAwaitingSecondPress)

        let decision = state.handleCommandQKeyDown(now: 2_000, config: config)
        XCTAssertEqual(decision, .blockAndPrompt(.confirmExit(window: 1)))
    }

    /// 验证清理回调尚未执行时，到达或超过截止时间的按键仍重新要求确认。
    func testConfirmationDeadlineDoesNotDependOnTimerDelivery() {
        for elapsed: TimeInterval in [1000, 1500] {
            let state = QuitGuardState()
            let config = makeConfig(doubleTap: 1)
            _ = state.handleCommandQKeyDown(now: 0, config: config)
            state.markKeyUp()
            XCTAssertEqual(
                state.handleCommandQKeyDown(now: elapsed, config: config),
                .blockAndPrompt(.confirmExit(window: 1))
            )
            state.reset()
        }
    }

    /// 验证截止时间前的第二次真实按压仍可确认退出。
    func testConfirmationImmediatelyBeforeDeadlinePasses() {
        let state = QuitGuardState()
        let config = makeConfig(doubleTap: 1)
        _ = state.handleCommandQKeyDown(now: 0, config: config)
        state.markKeyUp()
        XCTAssertEqual(state.handleCommandQKeyDown(now: 999, config: config), .passAndReset(nil))
    }

    /// 验证确认过期不会清除仍按住的 Q 键，重复按压仍按长按处理。
    func testExpiredConfirmationPreservesHeldKeyTracking() {
        let state = QuitGuardState()
        let config = makeConfig(doubleTap: 1)
        _ = state.handleCommandQKeyDown(now: 0, config: config)
        XCTAssertEqual(
            state.handleCommandQKeyDown(now: 1500, config: config),
            .passAndReset(.forwardedLongPress)
        )
        state.markKeyUp()
        XCTAssertEqual(
            state.handleCommandQKeyDown(now: 1600, config: config),
            .blockAndPrompt(.confirmExit(window: 1))
        )
        state.reset()
    }

    /// 验证确认退出的第二次按压在松开前持续透传，不会把同一次按压误当成下一轮首次确认。
    func testConfirmedPressRepeatsPassUntilRelease() {
        let state = QuitGuardState()
        let config = makeConfig()
        _ = state.handleCommandQKeyDown(now: 0, config: config)
        state.markKeyUp()
        XCTAssertEqual(state.handleCommandQKeyDown(now: 1000, config: config), .passAndReset(nil))
        XCTAssertEqual(state.handleCommandQKeyDown(now: 1100, config: config), .pass)
        XCTAssertEqual(state.handleCommandQKeyDown(now: 1200, config: config, isAutorepeat: true), .pass)
        state.markKeyUp()
        XCTAssertEqual(state.handleCommandQKeyDown(now: 1300, config: config), .blockAndPrompt(.confirmExit(window: 3)))
        state.reset()
    }

    func testLongPressDoesNotBecomeSecondConfirmation() {
        let config = makeConfig()
        let state = QuitGuardState()

        _ = state.handleCommandQKeyDown(now: 1_000, config: config)
        let longPress = state.handleCommandQKeyDown(now: 1_200, config: config)
        state.markKeyUp()
        let nextPress = state.handleCommandQKeyDown(now: 2_000, config: config)

        XCTAssertEqual(longPress, .passAndReset(.forwardedLongPress))
        XCTAssertEqual(nextPress, .blockAndPrompt(.confirmExit(window: 3)))
    }

    func testAutorepeatLongPressPassesUntilKeyUp() {
        let config = makeConfig()
        let state = QuitGuardState()

        _ = state.handleCommandQKeyDown(now: 1_000, config: config)
        let firstAutorepeat = state.handleCommandQKeyDown(
            now: 2_000,
            config: config,
            isAutorepeat: true
        )
        let nextAutorepeat = state.handleCommandQKeyDown(
            now: 2_100,
            config: config,
            isAutorepeat: true
        )

        XCTAssertEqual(firstAutorepeat, .passAndReset(.forwardedLongPress))
        XCTAssertEqual(nextAutorepeat, .pass)
        XCTAssertFalse(state.isAwaitingSecondPress)
        XCTAssertTrue(state.isLongPress)
    }

    func testLongPressRestartsConfirmationAfterKeyUp() {
        let config = makeConfig()
        let state = QuitGuardState()

        _ = state.handleCommandQKeyDown(now: 1_000, config: config)
        _ = state.handleCommandQKeyDown(now: 2_000, config: config, isAutorepeat: true)
        state.markKeyUp()
        let nextPress = state.handleCommandQKeyDown(now: 3_000, config: config)

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

    func testLongPressRepeatPassesButInitialPressStillIntercepts() {
        let handler = makeHandler(isBlockedApp: false)

        let firstDecision = handler.decision(
            for: commandQEvent(keyDown: true, flags: [.maskCommand]),
            eventType: .keyDown
        )
        let repeatDecision = handler.decision(
            for: commandQEvent(
                keyDown: true,
                flags: [.maskCommand],
                isAutorepeat: true
            ),
            eventType: .keyDown
        )

        XCTAssertEqual(firstDecision, .blockAndPrompt(.confirmExit(window: 3)))
        XCTAssertEqual(repeatDecision, .passAndReset(.forwardedLongPress))
    }

    /// 验证长按后以任意修饰键组合松开 Q，下一次按压都重新进入确认。
    func testLongPressEndsWhenQReleasedWithOtherModifiers() {
        let modifierCases: [CGEventFlags] = [[], .maskShift, .maskControl, .maskAlternate, [.maskShift, .maskAlternate]]
        for flags in modifierCases {
            let handler = makeHandler(isBlockedApp: false)
            _ = handler.decision(for: commandQEvent(keyDown: true, flags: [.maskCommand]), eventType: .keyDown)
            _ = handler.decision(
                for: commandQEvent(keyDown: true, flags: [.maskCommand], isAutorepeat: true), eventType: .keyDown
            )
            _ = handler.decision(for: commandQEvent(keyDown: false, flags: flags), eventType: .keyUp)
            XCTAssertEqual(
                handler.decision(for: commandQEvent(keyDown: true, flags: [.maskCommand]), eventType: .keyDown),
                .blockAndPrompt(.confirmExit(window: 3)), "flags=\(flags.rawValue)"
            )
        }
    }

    /// 验证短按以其他修饰键松开后，真实第二次按压仍能正常确认退出。
    func testShortPressReleasedWithShiftAllowsSecondConfirmation() {
        let handler = makeHandler(isBlockedApp: false)
        _ = handler.decision(for: commandQEvent(keyDown: true, flags: [.maskCommand]), eventType: .keyDown)
        _ = handler.decision(for: commandQEvent(keyDown: false, flags: [.maskShift]), eventType: .keyUp)
        XCTAssertEqual(
            handler.decision(for: commandQEvent(keyDown: true, flags: [.maskCommand]), eventType: .keyDown),
            .passAndReset(nil)
        )
    }

    func testCommandShiftQWillNotBeIntercepted() {
        let handler = makeHandler(isBlockedApp: false)
        let decision = handler.decision(
            for: commandQEvent(keyDown: true, flags: [.maskCommand, .maskShift]),
            eventType: .keyDown
        )

        XCTAssertEqual(decision, .pass)
    }

    func testCommandQEventClassifierReadsAutorepeatFlag() {
        let classifier = CommandQEventClassifier()
        let event = commandQEvent(
            keyDown: true,
            flags: [.maskCommand],
            isAutorepeat: true
        )

        XCTAssertEqual(
            classifier.classify(event: event, eventType: .keyDown),
            .keyDown(isAutorepeat: true)
        )
    }

    /// 验证同一次查询同时提供进程和路径，切换后不会沿用旧应用的白名单结论。
    func testApplicationSnapshotKeepsWhitelistAndProcessConsistent() {
        var application = QuitGuardApplication(processIdentifier: 100, bundlePath: "/Applications/Allowed.app")
        var queryCount = 0
        let handler = EventHandler(
            config: makeConfig(), state: QuitGuardState(),
            isBlockedApp: { $0 == "/Applications/Allowed.app" },
            currentApplication: { queryCount += 1; return application }
        )
        let down = commandQEvent(keyDown: true, flags: [.maskCommand])
        XCTAssertEqual(handler.decision(for: down, eventType: .keyDown), .pass)
        application = QuitGuardApplication(processIdentifier: 200, bundlePath: "/Applications/Protected.app")
        XCTAssertEqual(handler.decision(for: down, eventType: .keyDown), .blockAndPrompt(.confirmExit(window: 3)))
        XCTAssertEqual(queryCount, 2)
    }

    /// 验证进程号复用但应用路径不同的情形不会沿用确认窗口。
    func testReusedProcessIdentifierWithDifferentPathResetsConfirmation() {
        var path = "/Applications/A.app"
        let handler = EventHandler(
            config: makeConfig(), state: QuitGuardState(), isBlockedApp: { _ in false },
            currentApplication: { QuitGuardApplication(processIdentifier: 100, bundlePath: path) }
        )
        let down = commandQEvent(keyDown: true, flags: [.maskCommand])
        _ = handler.decision(for: down, eventType: .keyDown)
        _ = handler.decision(for: commandQEvent(keyDown: false, flags: []), eventType: .keyUp)
        path = "/Applications/B.app"
        XCTAssertEqual(handler.decision(for: down, eventType: .keyDown), .blockAndPrompt(.confirmExit(window: 3)))
    }

    /// 验证前台进程变化时，新应用的第一次退出仍需确认。
    func testSwitchingApplicationsStartsNewConfirmation() {
        var appPID: pid_t? = 100
        let handler = EventHandler(
            config: makeConfig(), state: QuitGuardState(), isBlockedApp: { _ in false },
            currentApplication: { appPID.map { QuitGuardApplication(processIdentifier: $0, bundlePath: nil) } }
        )
        _ = handler.decision(for: commandQEvent(keyDown: true, flags: [.maskCommand]), eventType: .keyDown)
        _ = handler.decision(for: commandQEvent(keyDown: false, flags: []), eventType: .keyUp)
        appPID = 200
        XCTAssertEqual(
            handler.decision(for: commandQEvent(keyDown: true, flags: [.maskCommand]), eventType: .keyDown),
            .blockAndPrompt(.confirmExit(window: 3))
        )
    }

    /// 验证切换出去再返回同一进程时，激活通知清理的状态不会复用。
    func testApplicationActivationResetDiscardsPendingConfirmation() {
        let handler = makeHandler(isBlockedApp: false)
        _ = handler.decision(for: commandQEvent(keyDown: true, flags: [.maskCommand]), eventType: .keyDown)
        _ = handler.decision(for: commandQEvent(keyDown: false, flags: []), eventType: .keyUp)
        handler.resetRuntimeState()
        XCTAssertEqual(
            handler.decision(for: commandQEvent(keyDown: true, flags: [.maskCommand]), eventType: .keyDown),
            .blockAndPrompt(.confirmExit(window: 3))
        )
    }

    /// 验证无法识别前台进程时不会把两次按键合并成退出确认。
    func testUnknownApplicationDoesNotReuseConfirmation() {
        let handler = EventHandler(
            config: makeConfig(), state: QuitGuardState(), isBlockedApp: { _ in false },
            currentApplication: { nil }
        )
        _ = handler.decision(for: commandQEvent(keyDown: true, flags: [.maskCommand]), eventType: .keyDown)
        _ = handler.decision(for: commandQEvent(keyDown: false, flags: []), eventType: .keyUp)
        XCTAssertEqual(
            handler.decision(for: commandQEvent(keyDown: true, flags: [.maskCommand]), eventType: .keyDown),
            .blockAndPrompt(.confirmExit(window: 3))
        )
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

    func testForwardedLongPressPromptUsesSecondaryStyle() {
        let prompt = QuitPrompt.forwardedLongPress

        XCTAssertEqual(prompt.title, "长按已交由应用处理")
        XCTAssertEqual(prompt.message, "当前应用将按自身规则处理退出")
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

    /// 验证早先排队的 ready 回调不会覆盖后来确认的缺权限状态。
    @MainActor
    func testQueuedReadyDoesNotOverrideNewerMissingPermission() {
        let available = QuitGuardAvailability(isAccessibilityTrusted: true, hasListenEventAccess: true)
        let missing = QuitGuardAvailability(isAccessibilityTrusted: false, hasListenEventAccess: true)
        let store = QuitGuardRuntimeStore(status: .ready)
        let tap = TapControllerSpy(currentTapSnapshot: TapSnapshot(
            currentLocation: .session, currentOption: .defaultTap, isEnabled: true, lastFailureReason: nil, attempts: []
        ))
        var callback: ((QuitGuardRuntimeStatus) -> Void)?
        let delegate = AppDelegate(
            config: makeConfig(), state: QuitGuardState(),
            permissionService: PermissionServiceSpy(currentAvailability: available),
            diagnosticService: makeDiagnosticService(), telemetry: TelemetrySpy(), runtimeStore: store,
            eventTapControllerFactory: { _, _, status in callback = status; return tap }
        )
        delegate.syncQuitGuardStatus(with: available, refreshTap: false)
        callback?(.ready)
        delegate.syncQuitGuardStatus(with: missing, refreshTap: false)
        waitForAsyncWork()
        XCTAssertEqual(store.status, .missingPermissions([.accessibility]))
    }

    /// 验证系统停用回调使用最新权限，而不是上次启动时缓存的授权状态。
    @MainActor
    func testTapDisableRechecksRevokedPermission() {
        let service = PermissionServiceSpy(currentAvailability: QuitGuardAvailability(isAccessibilityTrusted: true, hasListenEventAccess: true))
        let store = QuitGuardRuntimeStore(status: .ready)
        let tap = TapControllerSpy(currentTapSnapshot: TapSnapshot(
            currentLocation: .session, currentOption: .defaultTap, isEnabled: false,
            lastFailureReason: .tapDisabledBySystem, attempts: []
        ))
        let delegate = makeAppDelegate(permissionService: service, runtimeStore: store, tapSpy: tap)
        _ = delegate.readAvailability(promptAccessibility: false)
        service.currentValue = QuitGuardAvailability(isAccessibilityTrusted: false, hasListenEventAccess: true)
        delegate.syncRuntimeStatus(.tapDisabled)
        XCTAssertEqual(store.status, .missingPermissions([.accessibility]))
        XCTAssertEqual(tap.stopCallCount, 1)
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

    /// 验证权限满足但签名无效时会被环境诊断阻断。
    @MainActor
    func testAppDelegateLaunchBlocksWhenCodeSignatureIsInvalid() {
        let permissionSpy = PermissionServiceSpy(
            currentAvailability: QuitGuardAvailability(
                isAccessibilityTrusted: true,
                hasListenEventAccess: true
            )
        )
        let runtimeStore = QuitGuardRuntimeStore()
        let tapSpy = TapControllerSpy()
        let telemetrySpy = TelemetrySpy()
        let delegate = makeAppDelegate(
            permissionService: permissionSpy,
            runtimeStore: runtimeStore,
            tapSpy: tapSpy,
            diagnosticService: DiagnosticServiceSpy { _, _ in
                self.makeDiagnosticSnapshot(
                    suspectedFailureReason: .invalidCodeSignature
                )
            },
            telemetry: telemetrySpy
        )

        let availability = delegate.readAvailability(promptAccessibility: true)
        delegate.syncQuitGuardStatus(with: availability, refreshTap: false)
        XCTAssertEqual(runtimeStore.status, .blockedByEnvironment(.invalidCodeSignature))
        XCTAssertEqual(tapSpy.startCallCount, 0)
        XCTAssertEqual(tapSpy.stopCallCount, 1)
        XCTAssertEqual(telemetrySpy.events, [.environmentDiagnosed, .launchSync])
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

    /// 验证唤醒后即使权限仍满足，也不会忽略环境阻断继续刷新 tap。
    @MainActor
    func testAppDelegateWakeBlocksWhenEnvironmentIsUnavailable() {
        let permissionSpy = PermissionServiceSpy(
            currentAvailability: QuitGuardAvailability(
                isAccessibilityTrusted: true,
                hasListenEventAccess: true
            )
        )
        let runtimeStore = QuitGuardRuntimeStore(status: .ready)
        let tapSpy = TapControllerSpy()
        let delegate = makeAppDelegate(
            permissionService: permissionSpy,
            runtimeStore: runtimeStore,
            tapSpy: tapSpy,
            diagnosticService: DiagnosticServiceSpy { _, _ in
                self.makeDiagnosticSnapshot(
                    suspectedFailureReason: .invalidCodeSignature
                )
            }
        )

        let availability = delegate.readAvailability(promptAccessibility: false)
        delegate.syncQuitGuardStatus(with: availability, refreshTap: true)
        XCTAssertEqual(runtimeStore.status, .blockedByEnvironment(.invalidCodeSignature))
        XCTAssertEqual(tapSpy.refreshCallCount, 0)
        XCTAssertEqual(tapSpy.stopCallCount, 1)
    }

    /// 验证控制器释放时底层端口同步失效，不再留下指向已释放对象的回调。
    func testEventTapPortIsInvalidatedWhenControllerDeinitializes() {
        let port = makeTestMachPort()
        var controller: EventTapController? = EventTapController(
            config: makeConfig(), handler: makeHandler(isBlockedApp: false),
            tapCreator: { _, _, _, _, _, _ in port }, tapEnabledChecker: { _ in true }
        )
        XCTAssertTrue(controller!.start())
        controller = nil
        XCTAssertFalse(CFMachPortIsValid(port))
        CFMachPortInvalidate(port)
    }

    /// 验证提示在入场回调执行前被关闭时，不会被旧动画回调重新显示。
    func testDismissedTipIsNotResurrectedByQueuedAnimation() {
        let model = TipOverlayModel(presentation: TipPresentation(prompt: .confirmExit(window: 3), duration: 3))
        model.present(prompt: .confirmExit(window: 3), duration: 3, animateIn: true)
        model.dismiss()
        waitForAsyncWork()
        XCTAssertFalse(model.isVisible)
    }

    /// 验证应用切换及停止都会撤销排队中的提示，不显示已经失效的确认。
    func testQueuedTipIsCancelledByResetAndStop() {
        var presentationCount = 0
        let controller = EventTapController(
            config: makeConfig(), handler: makeHandler(isBlockedApp: false),
            tapCreator: { _, _, _, _, _, _ in self.makeTestMachPort() },
            tapEnabledChecker: { _ in true }, tipPresenter: { _, _ in presentationCount += 1 }
        )
        XCTAssertTrue(controller.start())
        _ = controller.handle(event: commandQEvent(keyDown: true, flags: [.maskCommand]), eventType: .keyDown)
        controller.resetConfirmation()
        waitForAsyncWork()
        XCTAssertEqual(presentationCount, 0)
        _ = controller.handle(event: commandQEvent(keyDown: true, flags: [.maskCommand]), eventType: .keyDown)
        controller.stop()
        waitForAsyncWork()
        XCTAssertEqual(presentationCount, 0)
    }

    /// 验证 tap 创建失败时会立即回传失败状态。
    func testEventTapControllerStartReportsTapCreateFailure() {
        var statuses: [QuitGuardRuntimeStatus] = []
        let controller = EventTapController(
            config: makeConfig(),
            handler: makeHandler(isBlockedApp: false),
            statusHandler: { statuses.append($0) },
            tapCreator: { _, _, _, _, _, _ in nil }
        )

        XCTAssertFalse(controller.start())
        XCTAssertEqual(statuses, [.tapCreateFailed])
    }

    /// 验证主动停止后，排队中的自动恢复不会重新创建拦截。
    func testStoppingTapCancelsPendingRecovery() {
        var creationCount = 0
        let controller = EventTapController(
            config: makeConfig(), handler: makeHandler(isBlockedApp: false),
            tapCreator: { _, _, _, _, _, _ in
                creationCount += 1
                return self.makeTestMachPort()
            },
            tapEnabledChecker: { _ in true }
        )
        XCTAssertTrue(controller.start())
        controller.handleTapDisabled(.tapDisabledByTimeout)
        controller.stop()
        waitForAsyncWork()
        XCTAssertEqual(creationCount, 1)
        XCTAssertFalse(controller.currentTapSnapshot.isEnabled)
    }

    /// 验证停止后重新启动时，上一轮生命周期的恢复任务不会干扰新 tap。
    func testPreviousRecoveryDoesNotRebuildNewTap() {
        var creationCount = 0
        let controller = EventTapController(
            config: makeConfig(), handler: makeHandler(isBlockedApp: false),
            tapCreator: { _, _, _, _, _, _ in
                creationCount += 1
                return self.makeTestMachPort()
            },
            tapEnabledChecker: { _ in true }
        )
        defer { controller.stop() }
        XCTAssertTrue(controller.start())
        controller.handleTapDisabled(.tapDisabledByTimeout)
        controller.stop()
        XCTAssertTrue(controller.start())
        waitForAsyncWork()
        XCTAssertEqual(creationCount, 2)
        XCTAssertTrue(controller.currentTapSnapshot.isEnabled)
    }

    /// 验证连续停用通知只安排一次恢复，避免反复重建正常 tap。
    func testRepeatedTapDisableNotificationsShareOneRecovery() {
        var creationCount = 0
        let controller = EventTapController(
            config: makeConfig(), handler: makeHandler(isBlockedApp: false),
            tapCreator: { _, _, _, _, _, _ in
                creationCount += 1
                return self.makeTestMachPort()
            },
            tapEnabledChecker: { _ in true }
        )
        defer { controller.stop() }
        XCTAssertTrue(controller.start())
        controller.handleTapDisabled(.tapDisabledByTimeout)
        controller.handleTapDisabled(.tapDisabledByUserInput)
        waitForAsyncWork()
        XCTAssertEqual(creationCount, 2)
    }

    /// 验证 tap 被系统停用后，恢复成功会回传 ready。
    func testEventTapControllerReportsReadyAfterTapRecovers() {
        var statuses: [QuitGuardRuntimeStatus] = []
        var taps: [CFMachPort?] = [makeTestMachPort(), makeTestMachPort()]
        let controller = EventTapController(
            config: makeConfig(),
            handler: makeHandler(isBlockedApp: false),
            statusHandler: { statuses.append($0) },
            tapCreator: { _, _, _, _, _, _ in taps.removeFirst() },
            tapEnabledChecker: { _ in true }
        )

        XCTAssertTrue(controller.start())
        controller.handleTapDisabled(.tapDisabledByTimeout)
        waitForAsyncWork()
        XCTAssertEqual(statuses, [.tapDisabled, .ready])
    }

    /// 验证 tap 被系统停用后，恢复失败会回传创建失败状态。
    func testEventTapControllerReportsFailureWhenTapRecoveryFails() {
        var statuses: [QuitGuardRuntimeStatus] = []
        var taps: [CFMachPort?] = [makeTestMachPort(), nil, nil]
        let controller = EventTapController(
            config: makeConfig(),
            handler: makeHandler(isBlockedApp: false),
            statusHandler: { statuses.append($0) },
            tapCreator: { _, _, _, _, _, _ in taps.removeFirst() },
            tapEnabledChecker: { _ in true }
        )

        XCTAssertTrue(controller.start())
        controller.handleTapDisabled(.tapDisabledByUserInput)
        waitForAsyncWork()
        XCTAssertEqual(statuses, [.tapDisabled, .tapCreateFailed])
    }

    /// 验证系统报告启用失败时返回失败并释放端口，不会虚报已启用。
    func testTapEnableFailureIsReportedAndPortIsReleased() {
        let port = makeTestMachPort()
        var statuses: [QuitGuardRuntimeStatus] = []
        let controller = EventTapController(
            config: makeConfig(), handler: makeHandler(isBlockedApp: false),
            statusHandler: { statuses.append($0) },
            tapCreator: { _, _, _, _, _, _ in port },
            tapEnabledChecker: { _ in false }
        )
        XCTAssertFalse(controller.start())
        XCTAssertFalse(controller.currentTapSnapshot.isEnabled)
        XCTAssertEqual(controller.currentTapSnapshot.lastFailureReason, .tapEnableFailed)
        XCTAssertEqual(statuses, [.tapCreateFailed])
        XCTAssertFalse(CFMachPortIsValid(port))
    }

    /// 验证已有 tap 再次启用失败后会释放旧端口，并允许后续重新创建。
    func testExistingTapEnableFailureAllowsFreshStart() {
        var isEnabled = true
        var creationCount = 0
        let controller = EventTapController(
            config: makeConfig(), handler: makeHandler(isBlockedApp: false),
            tapCreator: { _, _, _, _, _, _ in
                creationCount += 1
                return self.makeTestMachPort()
            },
            tapEnabledChecker: { _ in isEnabled }
        )
        defer { controller.stop() }
        XCTAssertTrue(controller.start())
        isEnabled = false
        XCTAssertFalse(controller.start())
        isEnabled = true
        XCTAssertTrue(controller.start())
        XCTAssertEqual(creationCount, 2)
    }

    /// 验证自动恢复时即使创建成功，启用失败也不会发出 ready 状态。
    func testRecoveryDoesNotReportReadyWhenEnableFails() {
        var isEnabled = true
        var statuses: [QuitGuardRuntimeStatus] = []
        let controller = EventTapController(
            config: makeConfig(), handler: makeHandler(isBlockedApp: false),
            statusHandler: { statuses.append($0) },
            tapCreator: { _, _, _, _, _, _ in self.makeTestMachPort() },
            tapEnabledChecker: { _ in isEnabled }
        )
        defer { controller.stop() }
        XCTAssertTrue(controller.start())
        isEnabled = false
        controller.handleTapDisabled(.tapDisabledByTimeout)
        waitForAsyncWork()
        XCTAssertEqual(statuses, [.tapDisabled, .tapCreateFailed])
        XCTAssertEqual(controller.currentTapSnapshot.lastFailureReason, .tapEnableFailed)
    }

    /// 验证诊断保留启用失败原因并允许重新检查重试。
    func testDiagnosticReportsTapEnableFailureAsRetryable() {
        let snapshot = makeDiagnosticService().makeSnapshot(
            availability: QuitGuardAvailability(isAccessibilityTrusted: true, hasListenEventAccess: true),
            tapSnapshot: TapSnapshot(
                currentLocation: .session, currentOption: .defaultTap, isEnabled: false,
                lastFailureReason: .tapEnableFailed, attempts: []
            )
        )
        XCTAssertEqual(snapshot.suspectedFailureReason, .tapEnableFailed)
        XCTAssertTrue(snapshot.canActivateTap)
    }

    /// 验证 tap 创建失败时会记录全部策略尝试结果。
    func testEventTapControllerCapturesStrategyAttemptsWhenTapCreateFails() {
        let strategies = [
            EventTapStrategy(
                location: .cgSessionEventTap,
                placement: .headInsertEventTap,
                options: .defaultTap,
                locationName: .session,
                optionName: .defaultTap
            ),
            EventTapStrategy(
                location: .cghidEventTap,
                placement: .headInsertEventTap,
                options: .defaultTap,
                locationName: .hid,
                optionName: .defaultTap
            )
        ]
        let controller = EventTapController(
            config: makeConfig(),
            handler: makeHandler(isBlockedApp: false),
            strategies: strategies,
            tapCreator: { _, _, _, _, _, _ in nil }
        )

        XCTAssertFalse(controller.start())
        XCTAssertEqual(
            controller.currentTapSnapshot.attempts,
            [
                EventTapAttemptSnapshot(
                    location: .session,
                    option: .defaultTap,
                    succeeded: false
                ),
                EventTapAttemptSnapshot(
                    location: .hid,
                    option: .defaultTap,
                    succeeded: false
                )
            ]
        )
        XCTAssertEqual(
            controller.currentTapSnapshot.lastFailureReason,
            .tapCreateReturnedNil
        )
    }

    /// 验证签名无效时诊断服务会给出明确的环境阻断原因。
    func testQuitGuardDiagnosticServiceMarksInvalidCodeSignature() {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let service = QuitGuardDiagnosticService(
            processIdentifierProvider: { 9527 },
            bundleInfoProvider: {
                QuitGuardBundleInfo(
                    bundlePath: "/Applications/CQ.app",
                    bundleIdentifier: "com.yanque.CQ"
                )
            },
            codeSignatureReader: { _ in .invalid },
            sandboxStateReader: { _ in .unknown },
            dateProvider: { fixedDate }
        )

        let snapshot = service.makeSnapshot(
            availability: QuitGuardAvailability(
                isAccessibilityTrusted: true,
                hasListenEventAccess: true
            ),
            tapSnapshot: .idle
        )
        XCTAssertEqual(snapshot.pid, 9527)
        XCTAssertEqual(snapshot.codeSignatureStatus, .invalid)
        XCTAssertEqual(snapshot.suspectedFailureReason, .invalidCodeSignature)
        XCTAssertTrue(snapshot.hasInvalidEntitlements)
        XCTAssertFalse(snapshot.canActivateTap)
        XCTAssertEqual(snapshot.timestamp, fixedDate)
    }

    /// 验证退出保护遥测会把最新快照写入诊断文件并保留有限历史。
    func testQuitGuardTelemetryPersistsLatestSnapshot() {
        let folderName = "CQTests.\(UUID().uuidString)"
        let store = QuitGuardDiagnosticStore(
            fileName: "quit-guard-diagnostics.json",
            folderName: folderName
        )
        let telemetry = QuitGuardTelemetry(store: store, maxEntries: 2)
        let first = makeDiagnosticSnapshot(suspectedFailureReason: .tapCreateReturnedNil)
        let second = makeDiagnosticSnapshot(suspectedFailureReason: .invalidCodeSignature)

        telemetry.record(event: .tapCreateResult, snapshot: first)
        telemetry.record(event: .launchSync, snapshot: second)

        let report = store.loadReport()
        XCTAssertEqual(report?.latestEvent, .launchSync)
        XCTAssertEqual(report?.latestSnapshot, second)
        XCTAssertEqual(report?.entries.count, 2)
        XCTAssertEqual(report?.entries.last?.snapshot.suspectedFailureReason, .invalidCodeSignature)
    }

    /// 验证诊断文件写入失败时遥测会按降级路径继续执行。
    func testQuitGuardTelemetryDegradesWhenPersistenceFails() {
        let store = DiagnosticPersistenceSpy(saveResult: false)
        let telemetry = QuitGuardTelemetry(store: store, maxEntries: 2)

        telemetry.record(
            event: .launchSync,
            snapshot: makeDiagnosticSnapshot(suspectedFailureReason: .none)
        )

        XCTAssertEqual(store.saveCallCount, 1)
        XCTAssertEqual(store.savedReports.count, 1)
    }

    /// 验证保护状态变更会传递到菜单，且异常状态不再显示已启用。
    func testMenuPanelReflectsRuntimeStatusAndRechecks() {
        let updates = PassthroughSubject<QuitGuardRuntimeStatus, Never>()
        var recheckCount = 0
        let model = MenuPanelModel(
            config: makeConfig(), blackList: makeBlackList(),
            autoLaunchStatus: { .notRegistered }, setAutoLaunch: { _ in },
            runtimeStatus: .ready, runtimeUpdates: updates.eraseToAnyPublisher(),
            recheckProtectionAction: { recheckCount += 1 }
        )
        XCTAssertTrue(model.summaryText.contains("保护已启用"))
        updates.send(.tapCreateFailed)
        waitForAsyncWork()
        XCTAssertTrue(model.summaryText.contains("启动失败"))
        XCTAssertFalse(model.summaryText.contains("保护已启用"))
        model.recheckProtection()
        XCTAssertEqual(recheckCount, 1)
    }

    /// 验证失败信息优先于未应用设置提示，避免编辑草稿掩盖保护失效。
    func testMenuPanelKeepsFailureVisibleWithPendingSettings() {
        let model = makeMenuPanelModel(records: [])
        model.doubleTapIntervalDraft += 1
        XCTAssertTrue(model.summaryText.contains("保护已暂停"))
        XCTAssertTrue(model.summaryText.contains("未应用更改"))
    }

    /// 验证旧 tap 失败不会阻止手动重新创建，恢复成功后更新菜单运行态。
    @MainActor
    func testManualRecheckRetriesAfterTapFailure() {
        let availability = QuitGuardAvailability(isAccessibilityTrusted: true, hasListenEventAccess: true)
        let runtimeStore = QuitGuardRuntimeStore(status: .tapCreateFailed)
        let tapSpy = TapControllerSpy()
        let delegate = makeAppDelegate(
            permissionService: PermissionServiceSpy(currentAvailability: availability),
            runtimeStore: runtimeStore, tapSpy: tapSpy,
            diagnosticService: DiagnosticServiceSpy { _, _ in
                self.makeDiagnosticSnapshot(suspectedFailureReason: .tapCreateReturnedNil)
            }
        )
        delegate.recheckQuitGuard()
        XCTAssertEqual(tapSpy.refreshCallCount, 1)
        XCTAssertEqual(runtimeStore.status, .ready)
    }

    /// 验证保留沙箱时，历史创建失败不会让第一次手动重试只清状态而不尝试创建。
    @MainActor
    func testSandboxHistoricalTapFailureStillAllowsRetry() {
        let availability = QuitGuardAvailability(isAccessibilityTrusted: true, hasListenEventAccess: true)
        let tap = TapControllerSpy(currentTapSnapshot: TapSnapshot(
            currentLocation: nil, currentOption: nil, isEnabled: false,
            lastFailureReason: .tapCreateReturnedNil, attempts: []
        ))
        let delegate = makeAppDelegate(
            permissionService: PermissionServiceSpy(currentAvailability: availability),
            runtimeStore: QuitGuardRuntimeStore(status: .tapCreateFailed), tapSpy: tap,
            diagnosticService: QuitGuardDiagnosticService(
                codeSignatureReader: { _ in .valid }, sandboxStateReader: { _ in .enabled }
            )
        )
        delegate.syncQuitGuardStatus(with: availability, refreshTap: true)
        XCTAssertEqual(tap.refreshCallCount, 1)
    }

    /// 验证旧创建失败通知不能覆盖当前系统停用状态。
    @MainActor
    func testStaleCreateFailureDoesNotOverrideCurrentDisabledState() {
        let store = QuitGuardRuntimeStore(status: .tapDisabled)
        let tap = TapControllerSpy(currentTapSnapshot: TapSnapshot(
            currentLocation: .session, currentOption: .defaultTap, isEnabled: false,
            lastFailureReason: .tapDisabledBySystem, attempts: []
        ))
        let delegate = makeAppDelegate(
            permissionService: PermissionServiceSpy(currentAvailability: QuitGuardAvailability(isAccessibilityTrusted: true, hasListenEventAccess: true)),
            runtimeStore: store, tapSpy: tap
        )
        delegate.syncRuntimeStatus(.tapCreateFailed)
        XCTAssertEqual(store.status, .tapDisabled)
    }

    /// 验证权限撤销后停止、重新授权后恢复，未变化时不重复重建。
    @MainActor
    func testPermissionRefreshStopsAndRecoversWithoutRepeatedRebuilds() {
        let available = QuitGuardAvailability(isAccessibilityTrusted: true, hasListenEventAccess: true)
        let service = PermissionServiceSpy(currentAvailability: available)
        let store = QuitGuardRuntimeStore(status: .ready)
        let tap = TapControllerSpy()
        let delegate = makeAppDelegate(permissionService: service, runtimeStore: store, tapSpy: tap)
        _ = delegate.readAvailability(promptAccessibility: false)
        delegate.syncQuitGuardStatus(with: available, refreshTap: false)
        delegate.refreshPermissionsIfNeeded()
        XCTAssertEqual(tap.refreshCallCount, 0)
        service.currentValue = QuitGuardAvailability(isAccessibilityTrusted: true, hasListenEventAccess: false)
        delegate.refreshPermissionsIfNeeded()
        XCTAssertEqual(store.status, .missingPermissions([.listenEvent]))
        XCTAssertEqual(tap.stopCallCount, 1)
        service.currentValue = available
        delegate.refreshPermissionsIfNeeded()
        XCTAssertEqual(store.status, .ready)
        XCTAssertEqual(tap.refreshCallCount, 1)
        delegate.refreshPermissionsIfNeeded()
        XCTAssertEqual(tap.refreshCallCount, 1)
    }

    /// 验证没有收到停用通知时，健康检查仍能发现实际 tap 失效且不会虚报恢复成功。
    @MainActor
    func testHealthCheckDetectsDisabledTapWithoutPermissionChange() {
        let available = QuitGuardAvailability(isAccessibilityTrusted: true, hasListenEventAccess: true)
        let store = QuitGuardRuntimeStore(status: .ready)
        let tap = TapControllerSpy()
        let delegate = makeAppDelegate(
            permissionService: PermissionServiceSpy(currentAvailability: available), runtimeStore: store, tapSpy: tap
        )
        _ = delegate.readAvailability(promptAccessibility: false)
        delegate.syncQuitGuardStatus(with: available, refreshTap: false)
        tap.actualEnabledOverride = false
        delegate.refreshPermissionsIfNeeded()
        XCTAssertEqual(tap.refreshCallCount, 1)
        XCTAssertEqual(store.status, .tapCreateFailed)
        delegate.refreshPermissionsIfNeeded()
        XCTAssertEqual(tap.refreshCallCount, 1)
    }

    /// 验证停用通知处理期间被授权编排停止时，不会继续安排自动恢复。
    func testTapRecoveryIsAbortedWhenStatusHandlerStopsController() {
        var controller: EventTapController?
        var creationCount = 0
        controller = EventTapController(
            config: makeConfig(), handler: makeHandler(isBlockedApp: false),
            statusHandler: { status in if status == .tapDisabled { controller?.stop() } },
            tapCreator: { _, _, _, _, _, _ in creationCount += 1; return self.makeTestMachPort() },
            tapEnabledChecker: { _ in true }
        )
        defer { controller?.stop(); controller = nil }
        XCTAssertTrue(controller!.start())
        controller?.handleTapDisabled(.tapDisabledByTimeout)
        waitForAsyncWork()
        XCTAssertEqual(creationCount, 1)
        XCTAssertFalse(controller!.isCurrentlyEnabled)
    }

    /// 验证休眠期间忽略旧 ready 和权限轮询，唤醒时再读取权限恢复。
    @MainActor
    func testSleepRejectsCallbacksUntilWake() {
        let available = QuitGuardAvailability(isAccessibilityTrusted: true, hasListenEventAccess: true)
        let service = PermissionServiceSpy(currentAvailability: available)
        let store = QuitGuardRuntimeStore(status: .ready)
        let tap = TapControllerSpy()
        let delegate = makeAppDelegate(permissionService: service, runtimeStore: store, tapSpy: tap)
        delegate.handleWillSleep()
        delegate.syncRuntimeStatus(.ready)
        delegate.refreshPermissionsIfNeeded()
        XCTAssertEqual(store.status, .tapDisabled)
        XCTAssertTrue(service.promptAccessibilityValues.isEmpty)
        delegate.handleDidWake()
        XCTAssertEqual(store.status, .ready)
        XCTAssertEqual(tap.refreshCallCount, 1)
    }

    /// 验证请求监听权限成功后实际恢复保护，不只更新授权窗口文案。
    @MainActor
    func testListenPermissionRequestStartsProtectionWhenGranted() {
        let available = QuitGuardAvailability(isAccessibilityTrusted: true, hasListenEventAccess: true)
        let service = PermissionServiceSpy(
            currentAvailability: QuitGuardAvailability(isAccessibilityTrusted: true, hasListenEventAccess: false),
            requestedAvailability: available
        )
        let store = QuitGuardRuntimeStore(status: .missingPermissions([.listenEvent]))
        let tap = TapControllerSpy()
        let delegate = makeAppDelegate(permissionService: service, runtimeStore: store, tapSpy: tap)
        delegate.handleListenEventAccessRequest()
        XCTAssertEqual(store.status, .ready)
        XCTAssertEqual(tap.refreshCallCount, 1)
    }

    /// 验证可重试的 tap 故障不会被误当成不可恢复的环境限制。
    func testDiagnosticAllowsRetryForTransientTapFailures() {
        for reason: SuspectedFailureReason in [.tapCreateReturnedNil, .tapDisabledBySystem] {
            XCTAssertTrue(makeDiagnosticSnapshot(suspectedFailureReason: reason).canActivateTap)
        }
        XCTAssertFalse(makeDiagnosticSnapshot(suspectedFailureReason: .invalidCodeSignature).canActivateTap)
    }

    /// 验证注册或取消失败后开关保持系统实际状态，且显示错误信息。
    func testLoginItemFailureKeepsSystemState() {
        for status: SMAppService.Status in [.notRegistered, .enabled] {
            let model = MenuPanelModel(
                config: makeConfig(), blackList: makeBlackList(), autoLaunchStatus: { status },
                setAutoLaunch: { _ in throw NSError(domain: "CQTests.Login", code: 1) }
            )
            model.toggleLaunchAtLogin(status != .enabled)
            XCTAssertEqual(model.startAtLogin, status == .enabled)
            XCTAssertNotNil(model.autoLaunchError)
        }
    }

    /// 验证需要系统批准时显示待批准提示，并允许取消尚未生效的注册。
    func testLoginItemApprovalCanBeCancelledAndRefreshed() {
        var status = SMAppService.Status.notRegistered
        let model = MenuPanelModel(
            config: makeConfig(), blackList: makeBlackList(), autoLaunchStatus: { status },
            setAutoLaunch: { status = $0 ? .requiresApproval : .notRegistered }
        )
        model.toggleLaunchAtLogin(true)
        XCTAssertEqual(model.loginStatus, .requiresApproval)
        XCTAssertTrue(model.autoLaunchMessage?.contains("尚未生效") == true)
        model.toggleLaunchAtLogin(false)
        XCTAssertFalse(model.startAtLogin)
        XCTAssertNil(model.autoLaunchMessage)
        status = .enabled
        model.refreshAutoLaunchStatus()
        XCTAssertTrue(model.startAtLogin)
        XCTAssertNil(model.autoLaunchMessage)
    }

    /// 验证菜单和设置窗口使用同一个模型，并读取代理实际使用的配置。
    @MainActor
    func testMenuAndSettingsShareDelegateConfigurationAndDrafts() {
        let config = makeConfig(doubleTap: 7)
        let delegate = AppDelegate(
            config: config, state: QuitGuardState(),
            permissionService: PermissionServiceSpy(currentAvailability: QuitGuardAvailability(isAccessibilityTrusted: true, hasListenEventAccess: true)),
            diagnosticService: makeDiagnosticService(), telemetry: TelemetrySpy(), runtimeStore: QuitGuardRuntimeStore(status: .ready),
            eventTapControllerFactory: { _, _, _ in TapControllerSpy() }
        )
        let menu = delegate.makeMenuPanelModel()
        let settings = delegate.makeMenuPanelModel()
        XCTAssertTrue(menu === settings)
        XCTAssertEqual(menu.doubleTapIntervalDraft, 7)
        menu.doubleTapIntervalDraft = 6
        menu.applySettings()
        XCTAssertEqual(config.doubleTapInterval, 6)
        XCTAssertEqual(settings.doubleTapIntervalDraft, 6)
    }

    func testMenuPanelDraftsOnlyWriteAfterApply() {
        let config = makeConfig(doubleTap: 3, alert: 3)
        let model = MenuPanelModel(
            config: config,
            blackList: makeBlackList(),
            autoLaunchStatus: { .notRegistered },
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
            autoLaunchStatus: { .notRegistered },
            setAutoLaunch: { _ in },
            quitAction: {}
        )

        XCTAssertFalse(model.hasPendingChanges)
        model.doubleTapIntervalDraft = 6
        XCTAssertTrue(model.hasPendingChanges)
    }

    /// 验证损坏文件不会被当成空列表覆盖，修复文件后重试保留已有记录。
    func testCorruptWhitelistIsPreservedAndCanRecover() throws {
        let file = makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corrupt = Data("not-json".utf8)
        try corrupt.write(to: file)
        let list = BlackList(store: WhitelistStore(fileURL: file))
        XCTAssertFalse(list.append(data: "/Applications/B.app"))
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
        try JSONEncoder().encode(["/Applications/A.app"]).write(to: file)
        XCTAssertTrue(list.append(data: "/Applications/B.app"))
        XCTAssertEqual(list.records, ["/Applications/A.app", "/Applications/B.app"])
    }

    /// 验证运行期间文件损坏也不会在下一次修改时被覆盖。
    func testWhitelistCorruptionAfterLoadPreservesOriginalBytes() throws {
        let file = makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let list = BlackList(store: WhitelistStore(fileURL: file))
        XCTAssertTrue(list.append(data: "/Applications/A.app"))
        let corrupt = Data("truncated [".utf8)
        try corrupt.write(to: file)
        XCTAssertFalse(list.remove(data: "/Applications/A.app"))
        XCTAssertTrue(list.contains("/Applications/A.app"))
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }

    /// 验证保存失败不会更新白名单列表及索引，恢复磁盘后可重试成功。
    func testWhitelistWriteFailurePreservesRecordsAndIndex() throws {
        let directory = makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("whitelist.json")
        let list = BlackList(store: WhitelistStore(fileURL: file))
        XCTAssertTrue(list.append(data: "/Applications/A.app"))
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        XCTAssertFalse(list.append(data: "/Applications/B.app"))
        XCTAssertFalse(list.remove(data: "/Applications/A.app"))
        XCTAssertEqual(list.records, ["/Applications/A.app"])
        XCTAssertTrue(list.contains("/Applications/A.app"))
        XCTAssertFalse(list.contains("/Applications/B.app"))
        try FileManager.default.removeItem(at: file)
        XCTAssertTrue(list.append(data: "/Applications/B.app"))
        XCTAssertEqual(list.records, ["/Applications/A.app", "/Applications/B.app"])
        XCTAssertEqual(WhitelistStore(fileURL: file).load(), list.records)
    }

    /// 验证添加失败后选择层继续显示错误并保留选择，恢复存储后可再次确认。
    func testAppPickerKeepsSelectionWhenWhitelistSaveFails() throws {
        let file = makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: file) }
        let list = BlackList(store: WhitelistStore(fileURL: file))
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        let item = makeAppPickerItem("/Applications/A.app")
        let model = makeMenuPanelModel(records: [], blackList: list, appCatalog: AppCatalogSpy(items: [item]))
        model.addWhitelistApp()
        waitForAsyncWork()
        model.selectAppPickerItem(item)
        model.confirmAppPickerSelection()
        XCTAssertTrue(model.isShowingAppPicker)
        XCTAssertEqual(model.selectedAppPickerItem, item)
        XCTAssertNotNil(model.whitelistError)
        XCTAssertTrue(list.records.isEmpty)
        try FileManager.default.removeItem(at: file)
        model.confirmAppPickerSelection()
        XCTAssertFalse(model.isShowingAppPicker)
        XCTAssertNil(model.whitelistError)
        XCTAssertTrue(list.contains(item.path))
    }

    /// 验证移除保存失败时面板展示错误并保留原有白名单及所选项。
    func testWhitelistRemovalFailureIsVisibleInMenu() throws {
        let file = makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let list = BlackList(store: WhitelistStore(fileURL: file))
        XCTAssertTrue(list.append(data: "/Applications/A.app"))
        let model = makeMenuPanelModel(records: [], blackList: list)
        model.selectWhitelistItem("/Applications/A.app")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        model.removeSelectedWhitelistItem()
        XCTAssertNotNil(model.whitelistError)
        XCTAssertEqual(model.whitelistItems, ["/Applications/A.app"])
        XCTAssertEqual(model.selectedWhitelistItem, "/Applications/A.app")
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
            catalog.loadApps(refresh: true).map { $0.path.replacingOccurrences(of: "/private", with: "") },
            [
                homeApps.appendingPathComponent("Arc.app").path,
                apps.appendingPathComponent("Safari.app").path,
                systemApps.appendingPathComponent("Utilities/Terminal.app").path
            ].map { $0.replacingOccurrences(of: "/private", with: "") }
        )
    }

    /// 验证重新打开应用选择层时能看到安装与卸载后的最新目录内容。
    func testAppPickerRefreshesAfterInstalledApplicationsChange() throws {
        let directory = makeTempDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let appA = directory.appendingPathComponent("A.app")
        let appB = directory.appendingPathComponent("B.app")
        try createAppBundle(at: appA)
        let catalog = InstalledAppCatalog(appDirectories: [directory.path])
        let model = makeMenuPanelModel(records: [], appCatalog: catalog)
        model.addWhitelistApp()
        waitForAsyncWork()
        XCTAssertEqual(model.appPickerItems.map(\.name), ["A"])
        model.dismissAppPicker()
        try FileManager.default.removeItem(at: appA)
        try createAppBundle(at: appB)
        model.addWhitelistApp()
        waitForAsyncWork()
        XCTAssertEqual(model.appPickerItems.map(\.name), ["B"])
    }

    /// 验证关闭后重新打开选择层时，旧扫描结果不能结束新一轮加载或覆盖新列表。
    func testOldCatalogResultDoesNotFinishReopenedPicker() {
        let firstStarted = expectation(description: "第一次扫描开始")
        let secondStarted = expectation(description: "第二次扫描开始")
        let catalog = BlockingAppCatalogSpy(firstStarted: { firstStarted.fulfill() }, secondStarted: { secondStarted.fulfill() })
        defer { catalog.firstRelease.signal(); catalog.secondRelease.signal() }
        let model = makeMenuPanelModel(records: [], appCatalog: catalog)
        model.addWhitelistApp()
        wait(for: [firstStarted], timeout: 1)
        model.dismissAppPicker()
        model.addWhitelistApp()
        catalog.firstRelease.signal()
        wait(for: [secondStarted], timeout: 1)
        waitForAsyncWork()
        XCTAssertTrue(model.isLoadingAppPicker)
        XCTAssertTrue(model.appPickerItems.isEmpty)
        catalog.secondRelease.signal()
        waitForAsyncWork()
        XCTAssertFalse(model.isLoadingAppPicker)
        XCTAssertEqual(model.appPickerItems.map(\.name), ["New"])
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
            autoLaunchStatus: { .notRegistered },
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
            isBlockedApp: { _ in isBlockedApp },
            currentApplication: { QuitGuardApplication(processIdentifier: 100, bundlePath: nil) }
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
        tapSpy: TapControllerSpy,
        diagnosticService: QuitGuardDiagnosing? = nil,
        telemetry: QuitGuardTelemetryWriting = TelemetrySpy()
    ) -> AppDelegate {
        AppDelegate(
            config: makeConfig(),
            state: QuitGuardState(),
            permissionService: permissionService,
            diagnosticService: diagnosticService ?? makeDiagnosticService(),
            telemetry: telemetry,
            runtimeStore: runtimeStore,
            eventTapControllerFactory: { _, _, _ in tapSpy }
        )
    }

    /// 构造用于测试的退出保护诊断服务，默认返回可启动的正常快照。
    /// - Returns: 便于测试覆盖的诊断服务实例。
    func makeDiagnosticService() -> QuitGuardDiagnosing {
        QuitGuardDiagnosticService(
            processIdentifierProvider: { 9527 },
            bundleInfoProvider: {
                QuitGuardBundleInfo(
                    bundlePath: "/Applications/CQ.app",
                    bundleIdentifier: "com.yanque.CQ"
                )
            },
            codeSignatureReader: { _ in .valid },
            sandboxStateReader: { _ in .disabled },
            dateProvider: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
    }

    /// 构造断言使用的结构化诊断快照。
    /// - Parameter suspectedFailureReason: 当前要写入快照的推断原因。
    /// - Returns: 可直接用于遥测或运行态断言的诊断结果。
    func makeDiagnosticSnapshot(
        suspectedFailureReason: SuspectedFailureReason
    ) -> QuitGuardDiagnosticSnapshot {
        QuitGuardDiagnosticSnapshot(
            pid: 9527,
            bundlePath: "/Applications/CQ.app",
            bundleIdentifier: "com.yanque.CQ",
            permissionSnapshot: PermissionSnapshot(
                isAccessibilityTrusted: true,
                hasListenEventAccess: true
            ),
            tapSnapshot: .idle,
            codeSignatureStatus: suspectedFailureReason == .invalidCodeSignature ? .invalid : .valid,
            declaredSandboxState: .disabled,
            hasInvalidEntitlements: suspectedFailureReason == .invalidCodeSignature,
            hasKnownUnsupportedEnvironment: suspectedFailureReason == .invalidCodeSignature,
            suspectedFailureReason: suspectedFailureReason,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    /// 构造 Cmd+Q 测试事件，并可按需标记为系统自动重复事件。
    /// - Parameters:
    ///   - keyDown: 是否为 keyDown 事件。
    ///   - flags: 事件携带的修饰键。
    ///   - isAutorepeat: 是否写入 autorepeat 标记。
    /// - Returns: 可交给事件处理器或分类器的 CGEvent。
    func commandQEvent(
        keyDown: Bool,
        flags: CGEventFlags,
        isAutorepeat: Bool = false
    ) -> CGEvent {
        let source = CGEventSource(stateID: .combinedSessionState)
        let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: 12,
            keyDown: keyDown
        )!
        event.flags = flags
        event.setIntegerValueField(
            .keyboardEventAutorepeat,
            value: isAutorepeat ? 1 : 0
        )
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
    var currentValue: QuitGuardAvailability
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
    var actualEnabledOverride: Bool?
    var isCurrentlyEnabled: Bool { actualEnabledOverride ?? currentTapSnapshot.isEnabled }
    private let startResult: Bool
    private let refreshResult: Bool
    private(set) var startCallCount: Int = 0
    private(set) var stopCallCount: Int = 0
    private(set) var refreshCallCount: Int = 0
    private(set) var currentTapSnapshot: TapSnapshot

    init(
        startResult: Bool = true,
        refreshResult: Bool = true,
        currentTapSnapshot: TapSnapshot = .idle
    ) {
        self.startResult = startResult
        self.refreshResult = refreshResult
        self.currentTapSnapshot = currentTapSnapshot
    }

    /// 记录启动调用次数，并返回预设结果。
    /// - Returns: 预设的启动结果。
    func start() -> Bool {
        startCallCount += 1
        updateSnapshot(enabled: startResult)
        return startResult
    }

    /// 测试桩无需显示提示，重置调用保持无副作用。
    func resetConfirmation() {}

    /// 记录停止调用次数。
    func stop() {
        stopCallCount += 1
        currentTapSnapshot = .idle
    }

    /// 记录恢复调用次数，并返回预设结果。
    /// - Returns: 预设的恢复结果。
    func refresh() -> Bool {
        refreshCallCount += 1
        updateSnapshot(enabled: refreshResult)
        return refreshResult
    }
    /// 与真实控制器一致地更新快照，让编排测试不依赖不可能的成功但未启用状态。
    private func updateSnapshot(enabled: Bool) {
        currentTapSnapshot = TapSnapshot(
            currentLocation: .session, currentOption: .defaultTap, isEnabled: enabled,
            lastFailureReason: enabled ? nil : .tapCreateReturnedNil, attempts: []
        )
    }

}

private final class DiagnosticServiceSpy: QuitGuardDiagnosing {
    private let snapshotProvider: (QuitGuardAvailability, TapSnapshot) -> QuitGuardDiagnosticSnapshot

    init(
        snapshotProvider: @escaping (QuitGuardAvailability, TapSnapshot) -> QuitGuardDiagnosticSnapshot
    ) {
        self.snapshotProvider = snapshotProvider
    }

    /// 返回预设的退出保护诊断快照，供编排测试使用。
    /// - Parameters:
    ///   - availability: 当前权限快照。
    ///   - tapSnapshot: 当前 tap 快照。
    /// - Returns: 预设的诊断结果。
    func makeSnapshot(
        availability: QuitGuardAvailability,
        tapSnapshot: TapSnapshot
    ) -> QuitGuardDiagnosticSnapshot {
        snapshotProvider(availability, tapSnapshot)
    }
}

private final class TelemetrySpy: QuitGuardTelemetryWriting {
    private(set) var events: [QuitGuardTelemetryEvent] = []
    private(set) var snapshots: [QuitGuardDiagnosticSnapshot] = []

    /// 记录编排测试里产生的遥测事件与快照。
    /// - Parameters:
    ///   - event: 当前记录的事件名。
    ///   - snapshot: 当前事件携带的诊断快照。
    func record(event: QuitGuardTelemetryEvent, snapshot: QuitGuardDiagnosticSnapshot) {
        events.append(event)
        snapshots.append(snapshot)
    }
}

private final class DiagnosticPersistenceSpy: QuitGuardDiagnosticPersisting {
    private let saveResult: Bool
    private(set) var saveCallCount: Int = 0
    private(set) var savedReports: [QuitGuardDiagnosticReport] = []

    init(saveResult: Bool) {
        self.saveResult = saveResult
    }

    /// 返回当前桩对象里暂存的最新诊断报告。
    /// - Returns: 最近一次写入过的诊断报告。
    func loadReport() -> QuitGuardDiagnosticReport? {
        savedReports.last
    }

    /// 记录遥测层尝试写入的诊断报告。
    /// - Parameter report: 本次待写入的诊断报告。
    /// - Returns: 预设的写入结果。
    func saveReport(_ report: QuitGuardDiagnosticReport) -> Bool {
        saveCallCount += 1
        savedReports.append(report)
        return saveResult
    }
}

/// 用有界等待控制两轮扫描返回顺序，复现关闭重开时的旧结果竞态。
private final class BlockingAppCatalogSpy: InstalledAppCataloging {
    let firstRelease = DispatchSemaphore(value: 0)
    let secondRelease = DispatchSemaphore(value: 0)
    private let firstStarted: () -> Void
    private let secondStarted: () -> Void
    private var loadCount = 0

    /// 注入扫描开始通知，测试无需依赖不确定的磁盘速度。
    init(firstStarted: @escaping () -> Void, secondStarted: @escaping () -> Void) {
        self.firstStarted = firstStarted
        self.secondStarted = secondStarted
    }

    /// 按串行扫描次序返回旧与新应用列表。
    func loadApps(refresh: Bool) -> [AppPickerItem] {
        loadCount += 1
        if loadCount == 1 {
            firstStarted()
            _ = firstRelease.wait(timeout: .now() + 3)
            return [AppPickerItem(url: URL(fileURLWithPath: "/Applications/Old.app"))]
        }
        secondStarted()
        _ = secondRelease.wait(timeout: .now() + 3)
        return [AppPickerItem(url: URL(fileURLWithPath: "/Applications/New.app"))]
    }
}
