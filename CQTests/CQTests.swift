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

    func testMenuPanelDraftsOnlyWriteAfterApply() {
        let config = makeConfig(doubleTap: 3, alert: 3)
        let model = MenuPanelModel(
            config: config,
            blackList: makeBlackList(),
            isAutoLaunchEnabled: { false },
            setAutoLaunch: { _ in },
            selectApp: { _ in },
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
            selectApp: { _ in },
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

    func testMenuButtonEventMaskSupportsLeftAndRightClick() {
        XCTAssertEqual(menuButtonEventMask, [.leftMouseUp, .rightMouseUp])
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

    func makeMenuPanelModel(records: [String]) -> MenuPanelModel {
        MenuPanelModel(
            config: makeConfig(),
            blackList: makeBlackList(records: records),
            isAutoLaunchEnabled: { false },
            setAutoLaunch: { _ in },
            selectApp: { _ in },
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

    func makeHandler(isBlockedApp: Bool) -> EventHandler {
        EventHandler(
            config: makeConfig(),
            state: QuitGuardState(),
            isBlockedApp: { isBlockedApp }
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
}
