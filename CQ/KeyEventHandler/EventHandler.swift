//
//  EventHandler.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation
import AppKit

/// 表示退出保护可处理的 Cmd+Q 键盘事件类型。
enum CommandQEventKind: Equatable {
    case keyDown(isAutorepeat: Bool)
    case keyUp
}

/// 负责把底层键盘事件归类为 CQ 关心的 Cmd+Q 事件，隔离 CGEvent 细节。
final class CommandQEventClassifier {
    private let commandQKeyCode: Int64
    private let trackedModifiers: CGEventFlags

    /// 初始化 Cmd+Q 事件分类器。
    /// - Parameters:
    ///   - commandQKeyCode: Q 键对应的虚拟键码。
    ///   - trackedModifiers: 参与精确匹配的修饰键集合。
    init(
        commandQKeyCode: Int64 = 12,
        trackedModifiers: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]
    ) {
        self.commandQKeyCode = commandQKeyCode
        self.trackedModifiers = trackedModifiers
    }

    /// 将底层 CGEvent 转换成退出保护可理解的 Cmd+Q 事件。
    /// - Parameters:
    ///   - event: 当前收到的键盘事件。
    ///   - eventType: 当前事件类型。
    /// - Returns: 可处理的 Cmd+Q 事件类型，不相关事件返回 nil。
    func classify(event: CGEvent, eventType: CGEventType) -> CommandQEventKind? {
        guard isRelevantKeyboardEvent(eventType) else { return nil }
        guard isCommandQKey(event) else { return nil }

        switch eventType {
        case .keyDown:
            guard hasExactCommandModifier(event.flags) else { return nil }
            return .keyDown(isAutorepeat: isAutorepeat(event))
        case .keyUp:
            return .keyUp
        default:
            return nil
        }
    }

    /// 判断当前 keyUp 是否应结束一次正在跟踪的 Cmd+Q 按压。
    /// - Parameters:
    ///   - flags: keyUp 事件携带的修饰键。
    ///   - isTrackingCommandQ: 当前状态机是否正在跟踪 Cmd+Q。
    /// - Returns: 是否应清理当前按压状态。
    func shouldTrackKeyUp(flags: CGEventFlags, isTrackingCommandQ: Bool) -> Bool {
        if !isTrackingCommandQ {
            return false
        }

        let modifiers = flags.intersection(trackedModifiers)
        return modifiers.contains(.maskCommand) || modifiers.isEmpty
    }

    /// 判断事件类型是否属于退出保护关心的键盘事件。
    /// - Parameter eventType: 当前事件类型。
    /// - Returns: 是否是 keyDown 或 keyUp。
    private func isRelevantKeyboardEvent(_ eventType: CGEventType) -> Bool {
        eventType == .keyDown || eventType == .keyUp
    }

    /// 判断当前事件是否来自 Q 键。
    /// - Parameter event: 当前键盘事件。
    /// - Returns: 是否命中 Q 键虚拟键码。
    private func isCommandQKey(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventKeycode) == commandQKeyCode
    }

    /// 判断 keyDown 是否只携带 Command 修饰键。
    /// - Parameter flags: 当前事件携带的修饰键。
    /// - Returns: 是否精确匹配 Cmd+Q。
    private func hasExactCommandModifier(_ flags: CGEventFlags) -> Bool {
        flags.intersection(trackedModifiers) == [.maskCommand]
    }

    /// 判断当前 keyDown 是否为系统自动重复事件。
    /// - Parameter event: 当前键盘事件。
    /// - Returns: 是否为 autorepeat。
    private func isAutorepeat(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    }
}

final class EventHandler {
    private let config: QuitGuardConfig
    private let state: QuitGuardState
    private let isBlockedApp: () -> Bool
    private let classifier: CommandQEventClassifier

    init(
        config: QuitGuardConfig,
        state: QuitGuardState,
        isBlockedApp: @escaping () -> Bool,
        classifier: CommandQEventClassifier = CommandQEventClassifier()
    ) {
        self.config = config
        self.state = state
        self.isBlockedApp = isBlockedApp
        self.classifier = classifier
    }

    func decision(for event: CGEvent, eventType: CGEventType) -> QuitDecision {
        guard let commandQEvent = classifier.classify(event: event, eventType: eventType) else {
            return .pass
        }

        switch commandQEvent {
        case .keyDown(let isAutorepeat):
            return handleKeyDown(isAutorepeat: isAutorepeat)
        case .keyUp:
            return handleKeyUp(event.flags)
        }
    }

    func resetRuntimeState() {
        state.reset()
    }

    /// 处理 Cmd+Q keyDown，并把白名单与长按状态转换成退出保护决策。
    /// - Parameter isAutorepeat: 当前 keyDown 是否为系统自动重复事件。
    /// - Returns: 本次 keyDown 对应的退出保护决策。
    private func handleKeyDown(isAutorepeat: Bool) -> QuitDecision {
        if isBlockedApp() {
            state.reset()
            return .pass
        }

        let now = Date().timeIntervalSince1970 * 1000
        let decision = state.handleCommandQKeyDown(
            now: now,
            config: config,
            isAutorepeat: isAutorepeat
        )
        if decision == .passAndReset(.ignoredLongPress) {
            AppLog.info("检测到长按 Cmd+Q，已透传重复退出事件")
        }
        return decision
    }

    /// 处理 Cmd+Q keyUp，并在一次按压结束时清理长按跟踪状态。
    /// - Parameter flags: keyUp 事件携带的修饰键。
    /// - Returns: keyUp 永远透传给前台应用。
    private func handleKeyUp(_ flags: CGEventFlags) -> QuitDecision {
        guard classifier.shouldTrackKeyUp(
            flags: flags,
            isTrackingCommandQ: state.isTrackingCommandQ
        ) else {
            return .pass
        }

        state.markKeyUp()
        return .pass
    }
}
