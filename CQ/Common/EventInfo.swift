//
//  EventInfo.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation

struct QuitGuardSettings {
    static let defaultValue = QuitGuardSettings()
    static let supportedInterval: ClosedRange<TimeInterval> = 1...8

    var doubleTapInterval: TimeInterval = 3
    var alertWindowCloseTime: TimeInterval = 3

    /// 将有限数值限制为界面支持的整数秒，非有限值使用对应默认值。
    static func validatedInterval(_ value: TimeInterval, fallback: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return fallback }
        return min(max(value, supportedInterval.lowerBound), supportedInterval.upperBound).rounded()
    }
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

    /// 保存前再次规范化数值，防止直接调用存储层写入非法配置。
    func save(_ settings: QuitGuardSettings) {
        userDefaults.set(
            QuitGuardSettings.validatedInterval(settings.doubleTapInterval, fallback: QuitGuardSettings.defaultValue.doubleTapInterval),
            forKey: Key.doubleTapInterval
        )
        userDefaults.set(
            QuitGuardSettings.validatedInterval(settings.alertWindowCloseTime, fallback: QuitGuardSettings.defaultValue.alertWindowCloseTime),
            forKey: Key.alertWindowCloseTime
        )
    }

    /// 只接受真正的数值类型，排除字符串与布尔值，并规范化范围及有限性。
    private func readValue(
        for key: String,
        default defaultValue: TimeInterval
    ) -> TimeInterval {
        guard let rawValue = userDefaults.object(forKey: key) else { return defaultValue }
        guard let number = rawValue as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
            AppLog.error("Invalid quit guard setting type: key=\(key); using default")
            return defaultValue
        }
        let value = number.doubleValue
        let validated = QuitGuardSettings.validatedInterval(value, fallback: defaultValue)
        if value != validated {
            AppLog.info("Normalized quit guard setting: key=\(key)")
        }
        return validated
    }
}

final class QuitGuardConfig {
    static let shared = QuitGuardConfig()

    private let store: QuitGuardSettingsStore

    private var settings: QuitGuardSettings

    var doubleTapInterval: TimeInterval {
        get { settings.doubleTapInterval }
        set {
            settings.doubleTapInterval = QuitGuardSettings.validatedInterval(
                newValue, fallback: QuitGuardSettings.defaultValue.doubleTapInterval
            )
            persist()
        }
    }

    var alertWindowCloseTime: TimeInterval {
        get { settings.alertWindowCloseTime }
        set {
            settings.alertWindowCloseTime = QuitGuardSettings.validatedInterval(
                newValue, fallback: QuitGuardSettings.defaultValue.alertWindowCloseTime
            )
            persist()
        }
    }

    /// 加载经过校验的配置，运行时赋值与持久化使用相同校验规则。
    init(store: QuitGuardSettingsStore = QuitGuardSettingsStore()) {
        self.store = store
        self.settings = store.load()
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
    case forwardedLongPress
}

extension QuitPrompt {
    var title: String {
        switch self {
        case .confirmExit:
            return "已拦截 Cmd+Q"
        case .forwardedLongPress:
            return "长按已交由应用处理"
        }
    }

    var message: String {
        switch self {
        case .confirmExit(let window):
            return "\(displaySeconds(for: window)) 秒内再按一次即可退出"
        case .forwardedLongPress:
            return "当前应用将按自身规则处理退出"
        }
    }

    var badgeText: String? {
        switch self {
        case .confirmExit:
            return "⌘Q"
        case .forwardedLongPress:
            return nil
        }
    }

    var symbolName: String {
        switch self {
        case .confirmExit:
            return "keyboard"
        case .forwardedLongPress:
            return "hand.tap.fill"
        }
    }

    var showsProgress: Bool {
        switch self {
        case .confirmExit:
            return true
        case .forwardedLongPress:
            return false
        }
    }

    private func displaySeconds(for window: TimeInterval) -> Int {
        max(1, Int(window.rounded(.up)))
    }
}

final class QuitGuardState {
    private var resetWorkItem: DispatchWorkItem?
    private var confirmationDeadline: TimeInterval?
    private var hasShownLongPressPrompt = false

    private(set) var isAwaitingSecondPress = false
    private(set) var firstCommandQTime: TimeInterval?
    private(set) var isLongPress = false

    var isTrackingCommandQ: Bool {
        firstCommandQTime != nil
    }

    /// 处理一次 Cmd+Q keyDown，并区分真实二次按下与未松手长按重复事件。
    /// - Parameters:
    ///   - now: 单调时钟上的事件时间，单位为毫秒。
    ///   - config: 当前退出保护配置。
    ///   - isAutorepeat: 当前 keyDown 是否为系统自动重复事件。
    /// - Returns: 本次 keyDown 对应的退出保护决策。
    func handleCommandQKeyDown(
        now: TimeInterval,
        config: QuitGuardConfig,
        isAutorepeat: Bool = false
    ) -> QuitDecision {
        if let confirmationDeadline, now >= confirmationDeadline {
            clearConfirmation()
        }
        if firstCommandQTime != nil || isAutorepeat {
            return passLongPress(now: now)
        }

        firstCommandQTime = now
        if !isAwaitingSecondPress {
            beginAwaitingSecondPress(now: now, timeout: config.doubleTapInterval)
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

    /// 清除确认期限及物理按压状态，用于切换应用、停止或确认退出。
    func reset() {
        clearConfirmation()
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
        clearConfirmation()
        isLongPress = true
        guard !hasShownLongPressPrompt else {
            return .pass
        }
        hasShownLongPressPrompt = true
        return .passAndReset(.forwardedLongPress)
    }

    /// 保存单调时钟截止时间，定时器仅负责及时清理过期确认。
    private func beginAwaitingSecondPress(now: TimeInterval, timeout: TimeInterval) {
        isAwaitingSecondPress = true
        confirmationDeadline = now + timeout * 1000
        scheduleReset(after: timeout)
    }

    /// 只清除确认窗口，保留尚未松开的 Q 键跟踪以正确识别长按。
    private func clearConfirmation() {
        cancelPendingReset()
        isAwaitingSecondPress = false
        confirmationDeadline = nil
    }

    /// 安排确认窗口清理；即使回调延迟，按键入口也会独立检查截止时间。
    private func scheduleReset(after timeout: TimeInterval) {
        cancelPendingReset()
        let workItem = DispatchWorkItem { [weak self] in
            self?.clearConfirmation()
        }
        resetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
    }

    private func cancelPendingReset() {
        resetWorkItem?.cancel()
        resetWorkItem = nil
    }
}
