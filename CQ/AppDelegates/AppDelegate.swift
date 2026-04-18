//
//  AppDelegate.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Cocoa
import Foundation
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    typealias EventTapControllerFactory = (
        QuitGuardConfig,
        EventHandler,
        @escaping (QuitGuardRuntimeStatus) -> Void
    ) -> QuitGuardControlling

    var statusItem: NSStatusItem?

    private let config: QuitGuardConfig
    private let state: QuitGuardState
    private let permissionService: QuitGuardPermissionChecking
    private let diagnosticService: QuitGuardDiagnosing
    private let telemetry: QuitGuardTelemetryWriting
    private let initialRuntimeStore: QuitGuardRuntimeStore?
    private let eventTapControllerFactory: EventTapControllerFactory
    let menuPopoverController = MenuPopoverController()
    private var noAccessWindow: NSWindow?
    private var runtimeStoreStorage: QuitGuardRuntimeStore?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lastAvailability: QuitGuardAvailability?

    override init() {
        self.config = .shared
        self.state = QuitGuardState()
        self.permissionService = QuitGuardPermissionService()
        self.diagnosticService = QuitGuardDiagnosticService()
        self.telemetry = QuitGuardTelemetry()
        self.initialRuntimeStore = nil
        self.eventTapControllerFactory = AppDelegate.defaultEventTapControllerFactory
        super.init()
    }

    init(
        config: QuitGuardConfig,
        state: QuitGuardState,
        permissionService: QuitGuardPermissionChecking,
        diagnosticService: QuitGuardDiagnosing,
        telemetry: QuitGuardTelemetryWriting,
        runtimeStore: QuitGuardRuntimeStore?,
        eventTapControllerFactory: @escaping EventTapControllerFactory
    ) {
        self.config = config
        self.state = state
        self.permissionService = permissionService
        self.diagnosticService = diagnosticService
        self.telemetry = telemetry
        self.initialRuntimeStore = runtimeStore
        self.eventTapControllerFactory = eventTapControllerFactory
        super.init()
    }

    private static let defaultEventTapControllerFactory: EventTapControllerFactory = {
        config,
        handler,
        statusHandler in
        EventTapController(
            config: config,
            handler: handler,
            statusHandler: statusHandler
        )
    }

    private lazy var eventHandler = EventHandler(
        config: config,
        state: state,
        isBlockedApp: { AppBlack.this.isCurrentAppBlocked() }
    )

    private lazy var eventTapController: QuitGuardControlling = {
        let statusHandler: (QuitGuardRuntimeStatus) -> Void = { [weak self] status in
            Task { @MainActor [weak self] in
                self?.syncRuntimeStatus(status)
            }
        }
        return eventTapControllerFactory(config, eventHandler, statusHandler)
    }()

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else {
            AppLog.info("检测到 XCTest 环境，跳过应用启动副作用")
            return
        }
        AppBlack.this.startObservingWorkspace()
        registerWorkspaceNotifications()
        configureQuitGuardAtLaunch()
        makeMenuButton()
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        guard !isRunningTests else { return }
        removeWorkspaceNotifications()
        AppBlack.this.stopObservingWorkspace()
        eventTapController.stop()
        closeAuthorizationWindow()
    }
}

extension AppDelegate {
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// 在主线程上下文中懒加载退出保护运行状态存储。
    @MainActor
    private var runtimeStore: QuitGuardRuntimeStore {
        if let runtimeStoreStorage {
            return runtimeStoreStorage
        }

        let store = initialRuntimeStore ?? QuitGuardRuntimeStore()
        runtimeStoreStorage = store
        return store
    }

    /// 启动后读取权限状态，并同步退出保护与授权窗口。
    @MainActor
    func configureQuitGuardAtLaunch() {
        let availability = readAvailability(promptAccessibility: true)
        AppLog.info("应用启动时同步退出保护: \(availability.logDescription)")
        recordDiagnostic(event: .permissionRefresh, availability: availability)
        syncQuitGuardStatus(with: availability, refreshTap: false)
        syncAuthorizationWindow(with: availability, showWhenMissing: true)
    }

    /// 系统唤醒后重新校验权限，并尝试恢复退出保护。
    @MainActor
    func configureQuitGuardAfterWake() {
        let availability = readAvailability(promptAccessibility: false)
        AppLog.info("系统唤醒后同步退出保护: \(availability.logDescription)")
        recordDiagnostic(event: .permissionRefresh, availability: availability)
        syncQuitGuardStatus(with: availability, refreshTap: true)
        syncAuthorizationWindow(with: availability, showWhenMissing: false)
    }

    /// 读取当前退出保护所依赖的权限快照。
    /// - Parameter promptAccessibility: 是否触发辅助功能权限提示。
    /// - Returns: 最新权限快照。
    func readAvailability(promptAccessibility: Bool) -> QuitGuardAvailability {
        let availability = permissionService.currentAvailability(promptAccessibility: promptAccessibility)
        lastAvailability = availability
        return availability
    }

    /// 根据权限快照启动或重建退出保护运行状态。
    /// - Parameters:
    ///   - availability: 最新权限快照。
    ///   - refreshTap: 是否按唤醒后的重建流程恢复 tap。
    @MainActor
    func syncQuitGuardStatus(with availability: QuitGuardAvailability, refreshTap: Bool) {
        let event: QuitGuardTelemetryEvent = refreshTap ? .wakeSync : .launchSync
        let diagnosticSnapshot = makeDiagnosticSnapshot(availability: availability)
        telemetry.record(event: .environmentDiagnosed, snapshot: diagnosticSnapshot)

        guard diagnosticSnapshot.canActivateTap else {
            AppLog.info("退出保护当前不可启动: \(diagnosticSnapshot.suspectedFailureReason.rawValue)")
            eventTapController.stop()
            applyBlockedRuntimeStatus(
                availability: availability,
                snapshot: diagnosticSnapshot
            )
            telemetry.record(event: event, snapshot: diagnosticSnapshot)
            return
        }

        guard availability.canStartIntercepting else {
            AppLog.info("退出保护缺少权限，停止 event tap: \(availability.logDescription)")
            eventTapController.stop()
            runtimeStore.markMissingPermissions(availability.missingPermissions)
            telemetry.record(event: event, snapshot: diagnosticSnapshot)
            return
        }

        let didActivate = refreshTap ? eventTapController.refresh() : eventTapController.start()
        let resultSnapshot = makeDiagnosticSnapshot(availability: availability)
        if !resultSnapshot.tapSnapshot.attempts.isEmpty {
            telemetry.record(event: .tapCreateAttempt, snapshot: resultSnapshot)
            telemetry.record(event: .tapCreateResult, snapshot: resultSnapshot)
        }
        telemetry.record(event: event, snapshot: resultSnapshot)
        AppLog.info(
            "退出保护同步完成: mode=\(refreshTap ? "refresh" : "start"), success=\(didActivate)"
        )
        updateRuntimeStatus(
            availability: availability,
            snapshot: resultSnapshot,
            didActivate: didActivate
        )
    }

    /// 把 event tap 生命周期变化写回运行状态。
    /// - Parameter status: 事件 tap 最新运行状态。
    @MainActor
    func syncRuntimeStatus(_ status: QuitGuardRuntimeStatus) {
        AppLog.info("退出保护运行状态更新: \(status.logDescription)")
        let previousStatus = runtimeStore.status
        runtimeStore.update(status: status)
        guard status == .tapDisabled || previousStatus == .tapDisabled else { return }
        let availability = currentAvailabilityForDiagnostics()
        let snapshot = makeDiagnosticSnapshot(availability: availability)
        let event: QuitGuardTelemetryEvent = status == .tapDisabled ? .tapDisabled : .tapRecoveryResult
        telemetry.record(event: event, snapshot: snapshot)
    }

    /// 按当前权限结果决定是否展示动态授权窗口。
    /// - Parameters:
    ///   - availability: 最新权限快照。
    ///   - showWhenMissing: 缺权限时是否主动展示窗口。
    @MainActor
    func syncAuthorizationWindow(
        with availability: QuitGuardAvailability,
        showWhenMissing: Bool
    ) {
        guard !availability.canStartIntercepting else {
            AppLog.info("退出保护权限已满足，关闭授权窗口")
            closeAuthorizationWindow()
            return
        }
        guard showWhenMissing else {
            AppLog.info("当前不主动展示授权窗口: \(availability.logDescription)")
            return
        }
        showAuthorizationWindow(for: availability)
    }

    /// 展示或刷新授权窗口内容。
    /// - Parameter availability: 当前用于渲染授权窗口的权限快照。
    @MainActor
    func showAuthorizationWindow(for availability: QuitGuardAvailability) {
        AppLog.info("展示授权窗口: \(availability.logDescription)")
        let rootView = makeNoAccessView(for: availability)
        if let noAccessWindow {
            noAccessWindow.contentViewController = NSHostingController(rootView: rootView)
            noAccessWindow.makeKeyAndOrderFront(self)
            noAccessWindow.orderFrontRegardless()
            return
        }

        noAccessWindow = rootView.openInWindow(title: "CQ请求授权", sender: self)
    }

    /// 关闭当前授权窗口并释放窗口引用。
    @MainActor
    func closeAuthorizationWindow() {
        guard noAccessWindow != nil else { return }
        AppLog.info("关闭授权窗口")
        noAccessWindow?.close()
        noAccessWindow = nil
    }

    /// 处理窗口内的事件监听权限请求，并刷新窗口展示内容。
    @MainActor
    func handleListenEventAccessRequest() {
        AppLog.info("用户点击请求事件监听权限")
        let availability = permissionService.requestListenEventAccess()
        lastAvailability = availability
        if !availability.canStartIntercepting {
            runtimeStore.markMissingPermissions(availability.missingPermissions)
        }
        AppLog.info("事件监听权限请求后的状态: \(availability.logDescription)")
        recordDiagnostic(event: .permissionRefresh, availability: availability)
        telemetry.record(event: .environmentDiagnosed, snapshot: makeDiagnosticSnapshot(availability: availability))
        showAuthorizationWindow(for: availability)
    }

    /// 构造授权窗口所需的动态视图。
    /// - Parameter availability: 当前权限快照。
    /// - Returns: 渲染授权状态的视图。
    @MainActor
    func makeNoAccessView(for availability: QuitGuardAvailability) -> NoAccessView {
        NoAccessView(
            availability: availability,
            openAccessSettings: AppDelegate.openAccessSettings,
            requestListenEventAccess: { [weak self] in
                self?.handleListenEventAccessRequest()
            },
            restartAction: AppDelegate.restartCQ
        )
    }

    @MainActor
    private func registerWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        let willSleep = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleWillSleep()
            }
        }

        let didWake = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleDidWake()
            }
        }

        workspaceObservers = [willSleep, didWake]
    }

    @MainActor
    private func removeWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers.removeAll()
    }

    @MainActor
    private func handleWillSleep() {
        AppLog.info("系统即将休眠，暂停事件拦截")
        eventTapController.stop()
    }

    @MainActor
    private func handleDidWake() {
        AppLog.info("系统已唤醒，重建事件拦截")
        AppBlack.this.refreshCurrentAppPath()
        configureQuitGuardAfterWake()
    }

    /// 生成当前运行态对应的退出保护诊断快照。
    /// - Parameter availability: 最近一次读取到的权限快照。
    /// - Returns: 汇总权限、tap 与环境后的诊断结果。
    @MainActor
    private func makeDiagnosticSnapshot(
        availability: QuitGuardAvailability
    ) -> QuitGuardDiagnosticSnapshot {
        diagnosticService.makeSnapshot(
            availability: availability,
            tapSnapshot: eventTapController.currentTapSnapshot
        )
    }

    /// 在权限或环境变化时统一记录诊断快照。
    /// - Parameters:
    ///   - event: 当前需要记录的诊断事件。
    ///   - availability: 事件发生时对应的权限快照。
    @MainActor
    private func recordDiagnostic(
        event: QuitGuardTelemetryEvent,
        availability: QuitGuardAvailability
    ) {
        telemetry.record(event: event, snapshot: makeDiagnosticSnapshot(availability: availability))
    }

    /// 根据诊断结果把运行态写回到统一的运行状态存储。
    /// - Parameters:
    ///   - availability: 当前权限快照。
    ///   - snapshot: 当前完整诊断快照。
    ///   - didActivate: 本次启动或恢复是否成功。
    @MainActor
    private func updateRuntimeStatus(
        availability: QuitGuardAvailability,
        snapshot: QuitGuardDiagnosticSnapshot,
        didActivate: Bool
    ) {
        if !availability.canStartIntercepting {
            runtimeStore.markMissingPermissions(availability.missingPermissions)
            return
        }
        if !snapshot.canActivateTap {
            runtimeStore.markBlockedByEnvironment(snapshot.suspectedFailureReason)
            return
        }
        didActivate ? runtimeStore.markReady() : runtimeStore.markTapCreateFailed()
    }

    /// 在退出保护被环境因素阻断时统一写回运行态。
    /// - Parameters:
    ///   - availability: 当前权限快照。
    ///   - snapshot: 当前完整诊断快照。
    @MainActor
    private func applyBlockedRuntimeStatus(
        availability: QuitGuardAvailability,
        snapshot: QuitGuardDiagnosticSnapshot
    ) {
        if !availability.canStartIntercepting {
            runtimeStore.markMissingPermissions(availability.missingPermissions)
            return
        }
        runtimeStore.markBlockedByEnvironment(snapshot.suspectedFailureReason)
    }

    /// 返回可用于遥测记录的最近权限快照，必要时会即时重新读取一次。
    /// - Returns: 当前仍可信的权限快照。
    @MainActor
    private func currentAvailabilityForDiagnostics() -> QuitGuardAvailability {
        if let lastAvailability {
            return lastAvailability
        }
        return readAvailability(promptAccessibility: false)
    }
}
