//
//  EventInfo.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation

struct QuitGuardSettings {
    static let defaultValue = QuitGuardSettings()

    var doubleTapInterval: TimeInterval = 3
    var alertWindowCloseTime: TimeInterval = 3
}

final class QuitGuardSettingsStore {
    private enum Key {
        static let doubleTapInterval = "quit_guard.double_tap_interval"
        static let alertWindowCloseTime = "quit_guard.alert_window_close_time"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> QuitGuardSettings {
        QuitGuardSettings(
            doubleTapInterval: readValue(
                for: Key.doubleTapInterval,
                default: QuitGuardSettings.defaultValue.doubleTapInterval
            ),
            alertWindowCloseTime: readValue(
                for: Key.alertWindowCloseTime,
                default: QuitGuardSettings.defaultValue.alertWindowCloseTime
            )
        )
    }

    func save(_ settings: QuitGuardSettings) {
        userDefaults.set(settings.doubleTapInterval, forKey: Key.doubleTapInterval)
        userDefaults.set(settings.alertWindowCloseTime, forKey: Key.alertWindowCloseTime)
    }

    private func readValue(
        for key: String,
        default defaultValue: TimeInterval
    ) -> TimeInterval {
        guard userDefaults.object(forKey: key) != nil else { return defaultValue }
        return userDefaults.double(forKey: key)
    }
}

final class QuitGuardConfig {
    static let shared = QuitGuardConfig()

    private let store: QuitGuardSettingsStore

    var doubleTapInterval: TimeInterval {
        didSet {
            persist()
        }
    }

    var alertWindowCloseTime: TimeInterval {
        didSet {
            persist()
        }
    }

    init(store: QuitGuardSettingsStore = QuitGuardSettingsStore()) {
        let settings = store.load()
        self.store = store
        self.doubleTapInterval = settings.doubleTapInterval
        self.alertWindowCloseTime = settings.alertWindowCloseTime
    }

    private var settings: QuitGuardSettings {
        QuitGuardSettings(
            doubleTapInterval: doubleTapInterval,
            alertWindowCloseTime: alertWindowCloseTime
        )
    }

    private func persist() {
        store.save(settings)
    }
}

enum QuitDecision: Equatable {
    case pass
    case blockAndPrompt(QuitPrompt)
    case passAndReset(QuitPrompt?)
}

enum QuitPrompt: Equatable {
    case confirmExit(window: TimeInterval)
    case ignoredLongPress
}

extension QuitPrompt {
    var title: String {
        switch self {
        case .confirmExit:
            return "已拦截 Cmd+Q"
        case .ignoredLongPress:
            return "已忽略长按 Cmd+Q"
        }
    }

    var message: String {
        switch self {
        case .confirmExit(let window):
            return "\(displaySeconds(for: window)) 秒内再按一次即可退出"
        case .ignoredLongPress:
            return "松开后重新按下，才会计入退出确认"
        }
    }

    var badgeText: String? {
        switch self {
        case .confirmExit:
            return "⌘Q"
        case .ignoredLongPress:
            return nil
        }
    }

    var symbolName: String {
        switch self {
        case .confirmExit:
            return "keyboard"
        case .ignoredLongPress:
            return "hand.tap.fill"
        }
    }

    var showsProgress: Bool {
        switch self {
        case .confirmExit:
            return true
        case .ignoredLongPress:
            return false
        }
    }

    private func displaySeconds(for window: TimeInterval) -> Int {
        max(1, Int(window.rounded(.up)))
    }
}

final class QuitGuardState {
    private var resetWorkItem: DispatchWorkItem?
    private var hasShownLongPressPrompt = false

    private(set) var isAwaitingSecondPress = false
    private(set) var firstCommandQTime: TimeInterval?
    private(set) var isLongPress = false

    var isTrackingCommandQ: Bool {
        firstCommandQTime != nil
    }

    /// 处理一次 Cmd+Q keyDown，并区分真实二次按下与未松手长按重复事件。
    /// - Parameters:
    ///   - now: 当前事件发生时间，单位为毫秒。
    ///   - config: 当前退出保护配置。
    ///   - isAutorepeat: 当前 keyDown 是否为系统自动重复事件。
    /// - Returns: 本次 keyDown 对应的退出保护决策。
    func handleCommandQKeyDown(
        now: TimeInterval,
        config: QuitGuardConfig,
        isAutorepeat: Bool = false
    ) -> QuitDecision {
        if firstCommandQTime != nil || isAutorepeat {
            return passLongPress(now: now)
        }

        firstCommandQTime = now
        if !isAwaitingSecondPress {
            beginAwaitingSecondPress(timeout: config.doubleTapInterval)
            return .blockAndPrompt(.confirmExit(window: config.doubleTapInterval))
        }

        reset()
        return .passAndReset(nil)
    }

    func markKeyUp() {
        firstCommandQTime = nil
        isLongPress = false
        hasShownLongPressPrompt = false
    }

    func reset() {
        cancelPendingReset()
        isAwaitingSecondPress = false
        firstCommandQTime = nil
        isLongPress = false
        hasShownLongPressPrompt = false
    }

    /// 透传长按 Cmd+Q 的重复 keyDown，并取消本轮 CQ 二次确认窗口。
    /// - Parameter now: 当前事件发生时间，单位为毫秒。
    /// - Returns: 首次长按返回提示并透传事件，后续同一轮长按只透传不重复提示。
    private func passLongPress(now: TimeInterval) -> QuitDecision {
        if firstCommandQTime == nil {
            firstCommandQTime = now
        }
        cancelPendingReset()
        isAwaitingSecondPress = false
        isLongPress = true
        guard !hasShownLongPressPrompt else {
            return .pass
        }
        hasShownLongPressPrompt = true
        return .passAndReset(.ignoredLongPress)
    }

    private func beginAwaitingSecondPress(timeout: TimeInterval) {
        isAwaitingSecondPress = true
        scheduleReset(after: timeout)
    }

    private func scheduleReset(after timeout: TimeInterval) {
        cancelPendingReset()
        let workItem = DispatchWorkItem { [weak self] in
            self?.reset()
        }
        resetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
    }

    private func cancelPendingReset() {
        resetWorkItem?.cancel()
        resetWorkItem = nil
    }
}
