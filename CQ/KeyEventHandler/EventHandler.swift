//
//  EventHandler.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation
import AppKit

final class EventHandler {
    private let commandQKeyCode: Int64 = 12
    private let trackedModifiers: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]

    private let config: QuitGuardConfig
    private let state: QuitGuardState
    private let isBlockedApp: () -> Bool

    init(
        config: QuitGuardConfig,
        state: QuitGuardState,
        isBlockedApp: @escaping () -> Bool
    ) {
        self.config = config
        self.state = state
        self.isBlockedApp = isBlockedApp
    }

    func decision(for event: CGEvent, eventType: CGEventType) -> QuitDecision {
        guard isRelevantKeyboardEvent(eventType) else {
            return .pass
        }

        guard isCommandQKey(event) else {
            return .pass
        }

        switch eventType {
        case .keyDown:
            return handleKeyDown(event.flags)
        case .keyUp:
            return handleKeyUp(event.flags)
        default:
            return .pass
        }
    }

    func resetRuntimeState() {
        state.reset()
    }

    private func handleKeyDown(_ flags: CGEventFlags) -> QuitDecision {
        guard hasExactCommandModifier(flags) else {
            return .pass
        }

        if isBlockedApp() {
            state.reset()
            return .pass
        }

        let now = Date().timeIntervalSince1970 * 1000
        return state.handleCommandQKeyDown(now: now, config: config)
    }

    private func handleKeyUp(_ flags: CGEventFlags) -> QuitDecision {
        guard shouldTrackKeyUp(flags) else {
            return .pass
        }

        state.markKeyUp()
        return .pass
    }

    private func isRelevantKeyboardEvent(_ eventType: CGEventType) -> Bool {
        eventType == .keyDown || eventType == .keyUp
    }

    private func isCommandQKey(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventKeycode) == commandQKeyCode
    }

    private func hasExactCommandModifier(_ flags: CGEventFlags) -> Bool {
        flags.intersection(trackedModifiers) == [.maskCommand]
    }

    private func shouldTrackKeyUp(_ flags: CGEventFlags) -> Bool {
        if !state.isTrackingCommandQ {
            return false
        }

        let modifiers = flags.intersection(trackedModifiers)
        return modifiers.contains(.maskCommand) || modifiers.isEmpty
    }
}
