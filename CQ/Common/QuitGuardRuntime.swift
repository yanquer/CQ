//
//  QuitGuardRuntime.swift
//  CQ
//
//  负责统一退出保护所需的权限检查、运行状态与事件拦截控制协议，
//  用来解决 Cmd+Q 拦截静默失效、权限来源分散、运行态不可观测的问题。
//

import ApplicationServices
import Combine
import Foundation

enum QuitGuardPermissionKind: String, CaseIterable, Equatable {
    case accessibility
    case listenEvent
}

extension QuitGuardPermissionKind {
    var title: String {
        switch self {
        case .accessibility:
            return "辅助功能"
        case .listenEvent:
            return "输入监控 / 事件监听"
        }
    }

    var detailText: String {
        switch self {
        case .accessibility:
            return "需要开启辅助功能权限，CQ 才能判断并阻止退出按键。"
        case .listenEvent:
            return "需要开启输入监控 / 事件监听权限，CQ 才能收到全局键盘事件。"
        }
    }
}

struct QuitGuardAvailability: Equatable {
    let isAccessibilityTrusted: Bool
    let hasListenEventAccess: Bool
    let missingPermissions: [QuitGuardPermissionKind]
    let canStartIntercepting: Bool

    init(
        isAccessibilityTrusted: Bool,
        hasListenEventAccess: Bool
    ) {
        let missingPermissions = QuitGuardAvailability.makeMissingPermissions(
            isAccessibilityTrusted: isAccessibilityTrusted,
            hasListenEventAccess: hasListenEventAccess
        )
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.hasListenEventAccess = hasListenEventAccess
        self.missingPermissions = missingPermissions
        self.canStartIntercepting = missingPermissions.isEmpty
    }

    var requiresAccessibilityPermission: Bool {
        missingPermissions.contains(.accessibility)
    }

    var requiresListenEventPermission: Bool {
        missingPermissions.contains(.listenEvent)
    }

    var headlineText: String {
        canStartIntercepting ? "权限已就绪" : "需要完成退出保护授权"
    }

    var messageText: String {
        canStartIntercepting
            ? "授权已经完成，点击“重启”后重新加载 Cmd+Q 拦截能力。"
            : "CQ 需要以下权限才能可靠拦截 Cmd+Q："
    }

    private static func makeMissingPermissions(
        isAccessibilityTrusted: Bool,
        hasListenEventAccess: Bool
    ) -> [QuitGuardPermissionKind] {
        var permissions: [QuitGuardPermissionKind] = []
        if !isAccessibilityTrusted {
            permissions.append(.accessibility)
        }
        if !hasListenEventAccess {
            permissions.append(.listenEvent)
        }
        return permissions
    }
}

enum QuitGuardRuntimeStatus: Equatable {
    case ready
    case missingPermissions([QuitGuardPermissionKind])
    case tapCreateFailed
    case tapDisabled
}

extension QuitGuardAvailability {
    /// 生成适合日志输出的权限摘要文本。
    var logDescription: String {
        let missing = missingPermissions.map(\.rawValue).joined(separator: ",")
        let missingText = missing.isEmpty ? "none" : missing
        return "accessibility=\(isAccessibilityTrusted), listenEvent=\(hasListenEventAccess), missing=\(missingText), canStart=\(canStartIntercepting)"
    }
}

extension QuitGuardRuntimeStatus {
    /// 生成适合日志输出的运行状态文本。
    var logDescription: String {
        switch self {
        case .ready:
            return "ready"
        case .tapCreateFailed:
            return "tapCreateFailed"
        case .tapDisabled:
            return "tapDisabled"
        case .missingPermissions(let permissions):
            let names = permissions.map(\.rawValue).joined(separator: ",")
            return "missingPermissions[\(names)]"
        }
    }
}

protocol QuitGuardPermissionChecking {
    /// 读取当前退出保护所需的权限状态。
    /// - Parameter promptAccessibility: 是否在读取辅助功能权限时触发系统提示。
    /// - Returns: 当前权限快照。
    func currentAvailability(promptAccessibility: Bool) -> QuitGuardAvailability

    /// 请求事件监听权限，并返回最新权限快照。
    /// - Returns: 请求后的权限快照。
    func requestListenEventAccess() -> QuitGuardAvailability
}

protocol QuitGuardControlling: AnyObject {
    /// 启动全局事件拦截，并返回是否创建成功。
    /// - Returns: 事件拦截是否成功启动。
    func start() -> Bool

    /// 停止当前事件拦截，并清理运行态。
    func stop()

    /// 重建全局事件拦截，并返回是否恢复成功。
    /// - Returns: 事件拦截是否成功恢复。
    func refresh() -> Bool
}

final class QuitGuardPermissionService: QuitGuardPermissionChecking {
    typealias AccessibilityChecking = (CFDictionary?) -> Bool
    typealias ListenEventChecking = () -> Bool
    typealias ListenEventRequesting = () -> Bool

    private let accessibilityChecker: AccessibilityChecking
    private let listenEventChecker: ListenEventChecking
    private let listenEventRequester: ListenEventRequesting
    private let processInfo: ProcessInfo

    init(
        accessibilityChecker: @escaping AccessibilityChecking = QuitGuardPermissionService.defaultAccessibilityChecker,
        listenEventChecker: @escaping ListenEventChecking = CGPreflightListenEventAccess,
        listenEventRequester: @escaping ListenEventRequesting = CGRequestListenEventAccess,
        processInfo: ProcessInfo = .processInfo
    ) {
        self.accessibilityChecker = accessibilityChecker
        self.listenEventChecker = listenEventChecker
        self.listenEventRequester = listenEventRequester
        self.processInfo = processInfo
    }

    /// 读取当前退出保护所需的权限状态。
    /// - Parameter promptAccessibility: 是否在读取辅助功能权限时触发系统提示。
    /// - Returns: 当前权限快照。
    func currentAvailability(promptAccessibility: Bool) -> QuitGuardAvailability {
        let availability = QuitGuardAvailability(
            isAccessibilityTrusted: checkAccessibility(promptAccessibility: promptAccessibility),
            hasListenEventAccess: listenEventChecker()
        )
        AppLog.info("读取退出保护权限: promptAccessibility=\(promptAccessibility), \(availability.logDescription)")
        return availability
    }

    /// 请求事件监听权限，并返回最新权限快照。
    /// - Returns: 请求后的权限快照。
    func requestListenEventAccess() -> QuitGuardAvailability {
        AppLog.info("开始请求事件监听权限")
        _ = listenEventRequester()
        let availability = QuitGuardAvailability(
            isAccessibilityTrusted: checkAccessibility(promptAccessibility: false),
            hasListenEventAccess: listenEventChecker()
        )
        AppLog.info("事件监听权限请求结束: \(availability.logDescription)")
        return availability
    }

    /// 按指定策略检查辅助功能权限。
    /// - Parameter promptAccessibility: 是否在检查时触发系统提示。
    /// - Returns: 当前是否已经获得辅助功能权限。
    private func checkAccessibility(promptAccessibility: Bool) -> Bool {
        accessibilityChecker(makeAccessibilityOptions(promptAccessibility: promptAccessibility))
    }

    /// 构造辅助功能权限检查所需的参数字典。
    /// - Parameter promptAccessibility: 是否需要弹出系统授权提示。
    /// - Returns: 传给辅助功能检查 API 的参数字典。
    private func makeAccessibilityOptions(promptAccessibility: Bool) -> CFDictionary? {
        guard promptAccessibility, !isRunningTests else { return nil }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: [String: Bool] = [promptKey: true]
        return options as CFDictionary
    }

    /// 判断当前是否处在 XCTest 驱动的测试环境中。
    private var isRunningTests: Bool {
        processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// 调用系统辅助功能 API，读取当前进程的信任状态。
    /// - Parameter options: 辅助功能检查参数。
    /// - Returns: 当前进程是否已被系统信任。
    private static func defaultAccessibilityChecker(options: CFDictionary?) -> Bool {
        AXIsProcessTrustedWithOptions(options)
    }
}

@MainActor
final class QuitGuardRuntimeStore: ObservableObject {
    @Published private(set) var status: QuitGuardRuntimeStatus

    init(
        status: QuitGuardRuntimeStatus = .missingPermissions([.accessibility, .listenEvent])
    ) {
        self.status = status
    }

    /// 更新当前退出保护运行状态。
    /// - Parameter status: 最新的运行状态。
    func update(status: QuitGuardRuntimeStatus) {
        self.status = status
    }

    /// 标记当前仍缺失的权限列表。
    /// - Parameter permissions: 仍未满足的权限集合。
    func markMissingPermissions(_ permissions: [QuitGuardPermissionKind]) {
        status = .missingPermissions(permissions)
    }

    /// 标记退出保护已经恢复为可用状态。
    func markReady() {
        status = .ready
    }

    /// 标记事件 tap 创建失败。
    func markTapCreateFailed() {
        status = .tapCreateFailed
    }

    /// 标记事件 tap 被系统停用。
    func markTapDisabled() {
        status = .tapDisabled
    }
}
