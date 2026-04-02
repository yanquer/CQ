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
    func testFirstCommandQRequiresConfirmation() {
        let config = makeConfig()
        let state = QuitGuardState()

        let decision = state.handleCommandQKeyDown(now: 1_000, config: config)

        XCTAssertEqual(decision, .blockAndPrompt("请再点击一次 CMD+Q 以退出"))
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
        XCTAssertEqual(decision, .blockAndPrompt("请再点击一次 CMD+Q 以退出"))
    }

    func testLongPressDoesNotBecomeSecondConfirmation() {
        let config = makeConfig()
        let state = QuitGuardState()

        _ = state.handleCommandQKeyDown(now: 1_000, config: config)
        let longPress = state.handleCommandQKeyDown(now: 1_200, config: config)
        state.markKeyUp()
        let nextPress = state.handleCommandQKeyDown(now: 2_000, config: config)

        XCTAssertEqual(longPress, .passAndReset("检测到为长按事件, 忽略"))
        XCTAssertEqual(nextPress, .blockAndPrompt("请再点击一次 CMD+Q 以退出"))
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

        XCTAssertEqual(firstDecision, .blockAndPrompt("请再点击一次 CMD+Q 以退出"))
        handler.resetRuntimeState()

        let secondDecision = handler.decision(
            for: commandQEvent(keyDown: true, flags: [.maskCommand]),
            eventType: .keyDown
        )

        XCTAssertEqual(secondDecision, .blockAndPrompt("请再点击一次 CMD+Q 以退出"))
    }
}

private extension CQTests {
    func makeConfig(doubleTap: TimeInterval = 3, alert: TimeInterval = 3) -> QuitGuardConfig {
        let config = QuitGuardConfig()
        config.doubleTapInterval = doubleTap
        config.alertWindowCloseTime = alert
        return config
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
