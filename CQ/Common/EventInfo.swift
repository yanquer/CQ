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
    private let longPressThreshold: TimeInterval = 700
    private var resetWorkItem: DispatchWorkItem?

    private(set) var isAwaitingSecondPress = false
    private(set) var firstCommandQTime: TimeInterval?
    private(set) var isLongPress = false

    var isTrackingCommandQ: Bool {
        firstCommandQTime != nil
    }

    func handleCommandQKeyDown(now: TimeInterval, config: QuitGuardConfig) -> QuitDecision {
        if updateLongPress(now: now) {
            reset()
            return .passAndReset(.ignoredLongPress)
        }

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
    }

    func reset() {
        cancelPendingReset()
        isAwaitingSecondPress = false
        firstCommandQTime = nil
        isLongPress = false
    }

    private func updateLongPress(now: TimeInterval) -> Bool {
        guard let firstCommandQTime else {
            self.firstCommandQTime = now
            return false
        }

        if isLongPress {
            return true
        }

        isLongPress = now - firstCommandQTime < longPressThreshold
        return isLongPress
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
