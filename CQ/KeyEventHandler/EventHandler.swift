//
//  EventHandler.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation
import AppKit
import Carbon

/// 表示退出保护可处理的 Cmd+Q 键盘事件类型。
enum CommandQEventKind: Equatable {
    case keyDown(isAutorepeat: Bool)
    case keyUp
}

/// 负责把底层键盘事件归类为 CQ 关心的 Cmd+Q 事件，隔离 CGEvent 细节。
final class CommandQEventClassifier {
    private let commandQKeyCode: Int64?
    private let keyCharacterProvider: (UInt16) -> String?
    private var trackedKeyCode: Int64?
    private let trackedModifiers: CGEventFlags

    /// 初始化 Cmd+Q 事件分类器。
    /// - Parameters:
    ///   - commandQKeyCode: 受控事件源可指定物理键码，默认按当前系统布局识别。
    ///   - trackedModifiers: 参与精确匹配的修饰键集合。
    ///   - keyCharacterProvider: 将物理键按 Command 状态翻译为当前布局字符。
    init(
        commandQKeyCode: Int64? = nil,
        trackedModifiers: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate],
        keyCharacterProvider: @escaping (UInt16) -> String? = CommandQEventClassifier.currentLayoutCharacter
    ) {
        self.commandQKeyCode = commandQKeyCode
        self.trackedModifiers = trackedModifiers
        self.keyCharacterProvider = keyCharacterProvider
    }

    /// 将底层 CGEvent 转换成退出保护可理解的 Cmd+Q 事件。
    /// - Parameters:
    ///   - event: 当前收到的键盘事件。
    ///   - eventType: 当前事件类型。
    /// - Returns: 可处理的 Cmd+Q 事件类型，不相关事件返回 nil。
    func classify(event: CGEvent, eventType: CGEventType) -> CommandQEventKind? {
        guard isRelevantKeyboardEvent(eventType) else { return nil }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        switch eventType {
        case .keyDown:
            guard hasExactCommandModifier(event.flags), isCommandQKey(event) else { return nil }
            trackedKeyCode = keyCode
            return .keyDown(isAutorepeat: isAutorepeat(event))
        case .keyUp:
            guard keyCode == trackedKeyCode else { return nil }
            trackedKeyCode = nil
            return .keyUp
        default:
            return nil
        }
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
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if let commandQKeyCode { return keyCode == commandQKeyCode }
        guard (0...127).contains(keyCode) else { return false }
        return keyCharacterProvider(UInt16(keyCode))?.lowercased() == "q"
    }

    /// 清除物理键跟踪，新的应用或拦截生命周期不能继承旧按压。
    func resetTracking() {
        trackedKeyCode = nil
    }

    /// 查询当前键盘布局，不修改输入源；输入法场景使用底层键盘布局。
    private static func currentLayoutCharacter(_ keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let rawData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(rawData).takeUnretainedValue()
        return character(for: keyCode, layoutData: data)
    }

    /// 按 Command 修饰状态翻译物理键，兼容 AZERTY、Dvorak 及 Command 下切换布局的键盘。
    static func character(for keyCode: UInt16, layoutData: CFData) -> String? {
        guard keyCode <= 127, CFDataGetLength(layoutData) >= MemoryLayout<UCKeyboardLayout>.size else { return nil }
        let layout = UnsafeRawPointer(CFDataGetBytePtr(layoutData)).assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let result = UCKeyTranslate(
            layout, keyCode, UInt16(kUCKeyActionDown), UInt32(cmdKey >> 8), UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState, characters.count, &length, &characters
        )
        guard result == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
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

/// 同一次前台查询得到的进程与路径，避免应用切换时混用旧白名单缓存。
struct QuitGuardApplication: Equatable {
    let processIdentifier: pid_t
    let bundlePath: String?

    /// 从同一个运行应用对象读取确认身份和白名单路径。
    static func frontmost() -> QuitGuardApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return QuitGuardApplication(processIdentifier: app.processIdentifier, bundlePath: app.bundleURL?.path)
    }
}

final class EventHandler {
    private let config: QuitGuardConfig
    private let state: QuitGuardState
    private let isBlockedApp: (String?) -> Bool
    private let classifier: CommandQEventClassifier
    private let currentApplication: () -> QuitGuardApplication?
    private var trackedApplication: QuitGuardApplication?

    /// 初始化退出事件处理器，并注入前台进程查询以隔离不同应用的确认状态。
    init(
        config: QuitGuardConfig,
        state: QuitGuardState,
        isBlockedApp: @escaping (String?) -> Bool,
        classifier: CommandQEventClassifier = CommandQEventClassifier(),
        currentApplication: @escaping () -> QuitGuardApplication? = QuitGuardApplication.frontmost
    ) {
        self.config = config
        self.state = state
        self.isBlockedApp = isBlockedApp
        self.classifier = classifier
        self.currentApplication = currentApplication
    }

    func decision(for event: CGEvent, eventType: CGEventType) -> QuitDecision {
        guard let commandQEvent = classifier.classify(event: event, eventType: eventType) else {
            return .pass
        }

        switch commandQEvent {
        case .keyDown(let isAutorepeat):
            return handleKeyDown(isAutorepeat: isAutorepeat)
        case .keyUp:
            return handleKeyUp()
        }
    }

    /// 清除退出确认和目标进程，避免应用切换或恢复后沿用旧状态。
    func resetRuntimeState() {
        trackedApplication = nil
        classifier.resetTracking()
        state.reset()
    }

    /// 处理 Cmd+Q keyDown，并把白名单与长按状态转换成退出保护决策。
    /// - Parameter isAutorepeat: 当前 keyDown 是否为系统自动重复事件。
    /// - Returns: 本次 keyDown 对应的退出保护决策。
    private func handleKeyDown(isAutorepeat: Bool) -> QuitDecision {
        let application = currentApplication()
        if application == nil || application != trackedApplication {
            state.reset()
            trackedApplication = application
        }
        if isBlockedApp(application?.bundlePath) {
            state.reset()
            return .pass
        }

        let now = ProcessInfo.processInfo.systemUptime * 1000
        let decision = state.handleCommandQKeyDown(
            now: now,
            config: config,
            isAutorepeat: isAutorepeat
        )
        if decision == .passAndReset(.forwardedLongPress) {
            AppLog.info("检测到长按 Cmd+Q，已透传重复退出事件")
        }
        return decision
    }

    /// Q 键松开即结束按压跟踪，不受松键时剩余修饰键影响。
    private func handleKeyUp() -> QuitDecision {
        guard state.isTrackingCommandQ else { return .pass }
        state.markKeyUp()
        return .pass
    }
}
