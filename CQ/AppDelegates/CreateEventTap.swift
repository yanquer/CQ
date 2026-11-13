//
//  CreateEventTap.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//
//  创建事件截取
//

import Foundation
import AppKit
import SwiftUI

final class TipPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// 创建可跨应用显示的非激活提示面板，兼容台前调度与全屏空间。
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .mainMenu
        // 提示需加入其他应用的台前调度分组，才能在 CQ 未激活时显示。
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .canJoinAllApplications]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
    }
}

/// 根据按键目标窗口的实际覆盖区域选择提示屏幕，窗口不可读时才使用鼠标位置。
enum TipScreenPlacement {
    /// 优先选择窗口覆盖面积最大的屏幕，空结果依次回退到鼠标所在屏幕与主屏幕。
    static func screenIndex(windowFrame: CGRect?, screenFrames: [CGRect], mouseLocation: CGPoint) -> Int? {
        var bestIndex: Int?
        var bestArea: CGFloat = 0
        if let windowFrame, !windowFrame.isNull, !windowFrame.isInfinite {
            for (index, frame) in screenFrames.enumerated() {
                let intersection = frame.intersection(windowFrame)
                guard !intersection.isNull else { continue }
                let area = intersection.width * intersection.height
                if area > bestArea {
                    bestIndex = index
                    bestArea = area
                }
            }
        }
        return bestIndex ?? screenFrames.firstIndex { $0.contains(mouseLocation) } ?? screenFrames.indices.first
    }

    /// 将辅助功能使用的左上原点坐标转为 AppKit 屏幕坐标，兼容上下排列及负坐标屏幕。
    static func appKitFrame(from accessibilityFrame: CGRect, primaryScreenTop: CGFloat) -> CGRect {
        CGRect(
            x: accessibilityFrame.minX,
            y: primaryScreenTop - accessibilityFrame.maxY,
            width: accessibilityFrame.width,
            height: accessibilityFrame.height
        )
    }

    /// 有界查询指定进程的焦点窗口，读取失败保留原始 AX 状态码供排查回退原因。
    static func focusedWindowFrame(processIdentifier: pid_t, primaryScreenTop: CGFloat) -> CGRect? {
        let application = AXUIElementCreateApplication(processIdentifier)
        let timeoutStatus = AXUIElementSetMessagingTimeout(application, 0.05)
        guard timeoutStatus == .success else {
            AppLog.error("Tip screen lookup failed: pid=\(processIdentifier), stage=applicationTimeout, axStatus=\(timeoutStatus.rawValue)")
            return nil
        }
        var rawWindow: CFTypeRef?
        let windowStatus = AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &rawWindow)
        guard windowStatus == .success, let rawWindow, CFGetTypeID(rawWindow) == AXUIElementGetTypeID() else {
            let message = "Tip screen lookup unavailable: pid=\(processIdentifier), stage=focusedWindow, axStatus=\(windowStatus.rawValue)"
            if windowStatus == .noValue || windowStatus == .attributeUnsupported {
                AppLog.info(message)
            } else {
                AppLog.error(message)
            }
            return nil
        }
        let window = rawWindow as! AXUIElement
        let windowTimeoutStatus = AXUIElementSetMessagingTimeout(window, 0.05)
        guard windowTimeoutStatus == .success else {
            AppLog.error("Tip screen lookup failed: pid=\(processIdentifier), stage=windowTimeout, axStatus=\(windowTimeoutStatus.rawValue)")
            return nil
        }
        var rawPosition: CFTypeRef?
        var rawSize: CFTypeRef?
        let positionStatus = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &rawPosition)
        let sizeStatus = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &rawSize)
        guard positionStatus == .success, sizeStatus == .success,
              let rawPosition, let rawSize,
              CFGetTypeID(rawPosition) == AXValueGetTypeID(), CFGetTypeID(rawSize) == AXValueGetTypeID() else {
            AppLog.error("Tip screen lookup failed: pid=\(processIdentifier), stage=geometry, positionStatus=\(positionStatus.rawValue), sizeStatus=\(sizeStatus.rawValue), validValues=false")
            return nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        let validPosition = AXValueGetValue(rawPosition as! AXValue, .cgPoint, &position)
        let validSize = AXValueGetValue(rawSize as! AXValue, .cgSize, &size)
        guard validPosition, validSize, position.x.isFinite, position.y.isFinite,
              size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
            AppLog.error("Tip screen lookup failed: pid=\(processIdentifier), stage=geometry, reason=invalidWindowFrame")
            return nil
        }
        return appKitFrame(from: CGRect(origin: position, size: size), primaryScreenTop: primaryScreenTop)
    }
}

final class EventTapController: QuitGuardControlling {
    typealias EventTapCreator = (
        CGEventTapLocation,
        CGEventTapPlacement,
        CGEventTapOptions,
        CGEventTapCallBack,
        UnsafeMutableRawPointer?,
        CGEventMask
    ) -> CFMachPort?

    private struct TapCreationResult {
        let tap: CFMachPort?
        let snapshot: TapSnapshot
    }

    private let config: QuitGuardConfig
    private let handler: EventHandler
    private let statusHandler: (QuitGuardRuntimeStatus) -> Void
    private let tapCreator: EventTapCreator
    private let tapEnabledChecker: (CFMachPort) -> Bool
    private let tipPresenter: ((QuitPrompt, TimeInterval, TipApplication?) -> Void)?
    private let tipTimeProvider: () -> TimeInterval
    private let strategies: [EventTapStrategy]
    private let tipAnimationDuration: TimeInterval = 0.18

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var recoveryWorkItem: DispatchWorkItem?
    private var lifecycleID = UUID()
    private var tipRequestID = UUID()
    private var tipWindow: TipPanel?
    private var tipModel: TipOverlayModel?
    private var tipCloseWorkItem: DispatchWorkItem?
    private var tipDismissWorkItem: DispatchWorkItem?

    private(set) var currentTapSnapshot: TapSnapshot = .idle

    /// 实时读取端口有效性与系统启用状态，供低频健康检查使用。
    var isCurrentlyEnabled: Bool {
        guard let tap else { return false }
        return CFMachPortIsValid(tap) && tapEnabledChecker(tap)
    }

    init(
        config: QuitGuardConfig,
        handler: EventHandler,
        statusHandler: @escaping (QuitGuardRuntimeStatus) -> Void = { _ in },
        strategies: [EventTapStrategy] = EventTapStrategy.defaultStrategies,
        tapCreator: @escaping EventTapCreator = EventTapController.defaultTapCreator,
        tapEnabledChecker: @escaping (CFMachPort) -> Bool = CGEvent.tapIsEnabled,
        tipPresenter: ((QuitPrompt, TimeInterval, TipApplication?) -> Void)? = nil,
        tipTimeProvider: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.config = config
        self.handler = handler
        self.statusHandler = statusHandler
        self.strategies = strategies
        self.tapCreator = tapCreator
        self.tapEnabledChecker = tapEnabledChecker
        self.tipPresenter = tipPresenter
        self.tipTimeProvider = tipTimeProvider
    }

    /// 释放时同步移除端口和回调，再清理主线程窗口，避免悬空 userInfo 和遗留资源。
    deinit {
        recoveryWorkItem?.cancel()
        tipCloseWorkItem?.cancel()
        tipDismissWorkItem?.cancel()
        removeTap()
        if let window = tipWindow { DispatchQueue.main.async { window.close() } }
    }

    /// 切换应用时同时重置按压状态与提示，旧应用的提示不能继续显示。
    func resetConfirmation() {
        handler.resetRuntimeState()
        closeTipWindow()
    }

    /// 启动事件拦截，并返回当前是否已经成功建立 tap。
    /// - Returns: 事件拦截是否可用。
    func start() -> Bool {
        if tap != nil {
            AppLog.info("event tap 已存在，直接尝试启用")
            let didEnable = enableTap()
            if !didEnable { removeTap() }
            return didEnable
        }

        AppLog.info("开始创建 event tap")
        return createTap()
    }

    /// 停止拦截并取消尚未执行的恢复，防止旧任务重新启动已停止的生命周期。
    func stop() {
        lifecycleID = UUID()
        recoveryWorkItem?.cancel()
        recoveryWorkItem = nil
        AppLog.info("停止 event tap 并清理运行态")
        handler.resetRuntimeState()
        destroyTipWindow()
        removeTap()
        markTapStopped()
    }

    /// 重建事件拦截，并返回恢复结果。
    /// - Returns: 事件拦截是否恢复成功。
    func refresh() -> Bool {
        AppLog.info("开始重建 event tap")
        stop()
        return start()
    }

    /// 创建底层 event tap，并在失败时回传运行状态。
    /// - Returns: event tap 是否创建成功。
    private func createTap() -> Bool {
        let callback = EventTapController.tapCallback
        let ref = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let result = buildTapCreationResult(
            callback: callback,
            ref: ref,
            eventMask: makeEventMask()
        )
        tap = result.tap
        currentTapSnapshot = result.snapshot

        guard let tap else {
            AppLog.info("创建 event tap 失败")
            statusHandler(.tapCreateFailed)
            return false
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let runLoopSource else {
            AppLog.info("创建 event tap run loop source 失败")
            removeTap()
            currentTapSnapshot = makeTapSnapshot(
                location: currentTapSnapshot.currentLocation,
                option: currentTapSnapshot.currentOption,
                isEnabled: false,
                failureReason: .tapCreateReturnedNil,
                attempts: currentTapSnapshot.attempts
            )
            statusHandler(.tapCreateFailed)
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        guard enableTap() else {
            removeTap()
            return false
        }
        AppLog.info("event tap 创建成功并已加入主运行循环")
        return true
    }

    /// 处理单个事件；测试直接传入事件对象，不向其他应用发送键盘输入。
    /// 返回借用引用，调用方需持有原事件直到使用完返回值。
    func handle(event: CGEvent, eventType: CGEventType) -> Unmanaged<CGEvent>? {
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            handleTapDisabled(eventType)
            return .passUnretained(event)
        }

        // 停止或停用之后的迟到事件只能透传，不能重新建立确认状态或显示提示。
        guard tap != nil, currentTapSnapshot.isEnabled else { return .passUnretained(event) }
        let decision = handler.decision(for: event, eventType: eventType)
        return output(for: decision, event: event)
    }

    private func output(for decision: QuitDecision, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch decision {
        case .pass:
            return .passUnretained(event)
        case .blockAndPrompt(let prompt):
            presentTip(prompt, duration: config.alertWindowCloseTime)
            return nil
        case .passAndReset(let prompt):
            if let prompt {
                presentTip(prompt, duration: 1)
            } else {
                closeTipWindow()
            }
            return .passUnretained(event)
        }
    }

    /// 排队显示提示前记录请求和生命周期，重置或停止后丢弃旧请求。
    private func presentTip(_ prompt: QuitPrompt, duration: TimeInterval) {
        let requestID = UUID()
        tipRequestID = requestID
        let expectedLifecycle = lifecycleID
        let requestedAt = tipTimeProvider()
        let application = handler.trackedApplication
        AppLog.info("Tip presentation requested: request=\(requestID), pid=\(application?.processIdentifier ?? 0), duration=\(duration)")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.lifecycleID == expectedLifecycle, self.tipRequestID == requestID else {
                AppLog.info("Tip presentation skipped: request=\(requestID), reason=requestInvalidated, lifecycleMatches=\(self.lifecycleID == expectedLifecycle), requestMatches=\(self.tipRequestID == requestID)")
                return
            }
            guard duration > max(0, self.tipTimeProvider() - requestedAt) else {
                AppLog.info("Tip presentation skipped: request=\(requestID), reason=queueDeadlineExpired")
                return
            }
            let screen = self.tipPresenter == nil ? self.currentTipScreen(for: application) : nil
            let tipApplication = TipApplication.resolve(application)
            // 窗口定位也可能耗时，须在定位后重新计算期限，避免延长提示及确认文案。
            let elapsed = max(0, self.tipTimeProvider() - requestedAt)
            let remainingDuration = duration - elapsed
            guard remainingDuration > 0 else {
                AppLog.info("Tip presentation skipped: request=\(requestID), reason=preparationDeadlineExpired, elapsed=\(elapsed)")
                return
            }
            AppLog.info("Tip presentation prepared: request=\(requestID), pid=\(application?.processIdentifier ?? 0), elapsed=\(elapsed), remainingDuration=\(remainingDuration)")
            let currentPrompt: QuitPrompt
            if case .confirmExit(let window) = prompt {
                currentPrompt = window > elapsed ? .confirmExit(window: window - elapsed) : .confirmationExpired
            } else {
                currentPrompt = prompt
            }
            if let tipPresenter = self.tipPresenter {
                tipPresenter(currentPrompt, remainingDuration, tipApplication)
            } else {
                self.presentTipOnMainThread(currentPrompt, duration: remainingDuration, application: tipApplication, screen: screen)
            }
        }
    }

    /// 关闭提示时使尚未显示的旧请求失效，新提示不受旧关闭回调影响。
    private func closeTipWindow() {
        let requestID = UUID()
        tipRequestID = requestID
        DispatchQueue.main.async { [weak self] in
            guard let self, self.tipRequestID == requestID else { return }
            self.dismissTipWindow(releaseResources: false)
        }
    }

    /// 停止拦截后释放当前生命周期的提示窗口，不影响后来启动的生命周期。
    private func destroyTipWindow() {
        tipRequestID = UUID()
        let expectedLifecycle = lifecycleID
        DispatchQueue.main.async { [weak self] in
            guard let self, self.lifecycleID == expectedLifecycle else { return }
            self.dismissTipWindow(releaseResources: true)
        }
    }

    /// 处理系统停用 event tap 的恢复流程，并把结果写回运行状态。
    /// - Parameter eventType: 系统返回的停用事件类型。
    func handleTapDisabled(_ eventType: CGEventType) {
        guard tap != nil, recoveryWorkItem == nil else { return }
        AppLog.info("event tap 已停用: \(eventType.rawValue)")
        markTapDisabled()
        let expectedLifecycleID = lifecycleID
        statusHandler(.tapDisabled)
        guard tap != nil, lifecycleID == expectedLifecycleID else { return }
        // 休眠唤醒后系统可能直接停用 tap，直接重建会比单纯 enable 更稳。
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.lifecycleID == expectedLifecycleID, self.tap != nil else { return }
            self.recoveryWorkItem = nil
            if self.refresh() {
                AppLog.info("event tap 恢复成功")
                self.statusHandler(.ready)
            } else {
                AppLog.error("event tap 恢复失败")
            }
        }
        recoveryWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func removeTap() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let tap {
            CFMachPortInvalidate(tap)
        }

        runLoopSource = nil
        tap = nil
    }

    private func makeEventMask() -> CGEventMask {
        let keyDown = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let keyUp = CGEventMask(1 << CGEventType.keyUp.rawValue)
        return keyDown | keyUp
    }

    /// 启用后读取系统实际状态，失败时保留诊断原因并返回失败，避免虚报保护成功。
    private func enableTap() -> Bool {
        guard let tap else { return false }
        CGEvent.tapEnable(tap: tap, enable: true)
        let isEnabled = CFMachPortIsValid(tap) && tapEnabledChecker(tap)
        currentTapSnapshot = makeTapSnapshot(
            location: currentTapSnapshot.currentLocation,
            option: currentTapSnapshot.currentOption,
            isEnabled: isEnabled,
            failureReason: isEnabled ? nil : .tapEnableFailed,
            attempts: currentTapSnapshot.attempts
        )
        if isEnabled {
            AppLog.info("event tap 已启用")
        } else {
            AppLog.error("Event tap enable failed: system reports disabled")
            statusHandler(.tapCreateFailed)
        }
        return isEnabled
    }

    /// 按预设策略依次尝试创建 event tap，并沉淀每次尝试结果。
    /// - Parameters:
    ///   - callback: event tap 回调。
    ///   - ref: 回调透传的控制器指针。
    ///   - eventMask: 需要监听的事件掩码。
    /// - Returns: 创建后的 tap 与对应快照。
    private func buildTapCreationResult(
        callback: @escaping CGEventTapCallBack,
        ref: UnsafeMutableRawPointer?,
        eventMask: CGEventMask
    ) -> TapCreationResult {
        var attempts: [EventTapAttemptSnapshot] = []
        for strategy in strategies {
            let tap = makeTap(strategy: strategy, callback: callback, ref: ref, eventMask: eventMask)
            attempts.append(makeAttemptSnapshot(strategy: strategy, succeeded: tap != nil))
            guard let tap else { continue }
            return TapCreationResult(
                tap: tap,
                snapshot: makeTapSnapshot(
                    location: strategy.locationName,
                    option: strategy.optionName,
                    isEnabled: false,
                    failureReason: nil,
                    attempts: attempts
                )
            )
        }
        return TapCreationResult(
            tap: nil,
            snapshot: makeTapSnapshot(
                location: nil,
                option: nil,
                isEnabled: false,
                failureReason: .tapCreateReturnedNil,
                attempts: attempts
            )
        )
    }

    /// 按给定策略向系统请求创建底层 event tap。
    /// - Parameters:
    ///   - strategy: 当前准备尝试的 tap 策略。
    ///   - callback: event tap 回调。
    ///   - ref: 回调透传的控制器指针。
    ///   - eventMask: 需要监听的事件掩码。
    /// - Returns: 系统返回的 event tap 端口。
    private func makeTap(
        strategy: EventTapStrategy,
        callback: @escaping CGEventTapCallBack,
        ref: UnsafeMutableRawPointer?,
        eventMask: CGEventMask
    ) -> CFMachPort? {
        tapCreator(
            strategy.location,
            strategy.placement,
            strategy.options,
            callback,
            ref,
            eventMask
        )
    }

    /// 把单次策略尝试转换成可落盘的快照记录。
    /// - Parameters:
    ///   - strategy: 当前尝试使用的 tap 策略。
    ///   - succeeded: 当前策略是否创建成功。
    /// - Returns: 对应策略的尝试结果。
    private func makeAttemptSnapshot(
        strategy: EventTapStrategy,
        succeeded: Bool
    ) -> EventTapAttemptSnapshot {
        EventTapAttemptSnapshot(
            location: strategy.locationName,
            option: strategy.optionName,
            succeeded: succeeded
        )
    }

    /// 构造当前控制器要暴露给外部的 tap 运行快照。
    /// - Parameters:
    ///   - location: 当前命中的 tap 位置。
    ///   - option: 当前命中的 tap 选项。
    ///   - isEnabled: tap 是否已经启用。
    ///   - failureReason: 最近一次 tap 失败原因。
    ///   - attempts: 最近一次创建流程的所有尝试记录。
    /// - Returns: 结构化的 tap 快照。
    private func makeTapSnapshot(
        location: EventTapLocationName?,
        option: EventTapOptionName?,
        isEnabled: Bool,
        failureReason: TapFailureReason?,
        attempts: [EventTapAttemptSnapshot]
    ) -> TapSnapshot {
        TapSnapshot(
            currentLocation: location,
            currentOption: option,
            isEnabled: isEnabled,
            lastFailureReason: failureReason,
            attempts: attempts
        )
    }

    /// 在控制器主动停止 tap 时回写关闭后的运行快照。
    private func markTapStopped() {
        currentTapSnapshot = makeTapSnapshot(
            location: currentTapSnapshot.currentLocation,
            option: currentTapSnapshot.currentOption,
            isEnabled: false,
            failureReason: nil,
            attempts: currentTapSnapshot.attempts
        )
    }

    /// 在系统停用 tap 时记录当前失败原因，供诊断模块读取。
    private func markTapDisabled() {
        currentTapSnapshot = makeTapSnapshot(
            location: currentTapSnapshot.currentLocation,
            option: currentTapSnapshot.currentOption,
            isEnabled: false,
            failureReason: .tapDisabledBySystem,
            attempts: currentTapSnapshot.attempts
        )
    }

    /// 构造默认的系统级 event tap 创建逻辑。
    /// - Parameters:
    ///   - location: 当前策略希望创建的 tap 位置。
    ///   - placement: 当前策略希望插入的 tap 位置。
    ///   - options: 当前策略使用的 tap 选项。
    ///   - callback: event tap 回调。
    ///   - userInfo: 回调透传上下文。
    ///   - eventMask: 需要监听的事件掩码。
    /// - Returns: 系统返回的 event tap 端口。
    private static func defaultTapCreator(
        location: CGEventTapLocation,
        placement: CGEventTapPlacement,
        options: CGEventTapOptions,
        callback: @escaping CGEventTapCallBack,
        userInfo: UnsafeMutableRawPointer?,
        eventMask: CGEventMask
    ) -> CFMachPort? {
        CGEvent.tapCreate(
            tap: location,
            place: placement,
            options: options,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        )
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, ref in
        guard let ref else {
            return .passUnretained(event)
        }

        let controller = Unmanaged<EventTapController>.fromOpaque(ref).takeUnretainedValue()
        return controller.handle(event: event, eventType: type)
    }
}

private extension EventTapController {
    var prefersReducedMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var tipDismissAnimationDuration: TimeInterval {
        prefersReducedMotion ? 0 : tipAnimationDuration
    }

    var tipWindowSize: CGSize {
        CGSize(width: TipViewSize.width, height: TipViewSize.height)
    }

    /// 使用按键时记录的目标进程读取窗口，避免鼠标留在另一块屏幕时提示错位。
    func currentTipScreen(for application: QuitGuardApplication?) -> NSScreen? {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return nil }
        let startedAt = ProcessInfo.processInfo.systemUptime
        AppLog.debug("Tip screen lookup started: pid=\(application?.processIdentifier ?? 0)")
        let windowFrame = application.flatMap {
            TipScreenPlacement.focusedWindowFrame(processIdentifier: $0.processIdentifier, primaryScreenTop: primary.frame.maxY)
        }
        let index = TipScreenPlacement.screenIndex(
            windowFrame: windowFrame, screenFrames: screens.map(\.frame), mouseLocation: NSEvent.mouseLocation
        )
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        let windowIsVisible = windowFrame.map { frame in screens.contains { $0.frame.intersects(frame) } } ?? false
        if !windowIsVisible {
            AppLog.info("Tip screen fallback: pid=\(application?.processIdentifier ?? 0), source=mouseOrPrimary, screenIndex=\(index ?? -1), elapsed=\(elapsed)")
        } else {
            AppLog.debug("Tip screen resolved: pid=\(application?.processIdentifier ?? 0), source=focusedWindow, screenIndex=\(index ?? -1), elapsed=\(elapsed)")
        }
        return index.map { screens[$0] }
    }

    /// 在非激活窗口中展示当前提示，并使用查询得到的目标屏幕。
    func presentTipOnMainThread(_ prompt: QuitPrompt, duration: TimeInterval, application: TipApplication?, screen: NSScreen?) {
        tipDismissWorkItem?.cancel()

        let window = ensureTipWindow(prompt: prompt, duration: duration, application: application)
        positionTipWindow(window, screen: screen)
        window.alphaValue = 1
        window.orderFrontRegardless()

        let shouldAnimateIn = !(tipModel?.isVisible ?? false)
        tipModel?.present(
            prompt: prompt,
            duration: duration,
            application: application,
            animateIn: shouldAnimateIn
        )
        AppLog.info("Tip window ordered: window=\(window.windowNumber), visible=\(window.isVisible), activeSpace=\(window.isOnActiveSpace), occlusionVisible=\(window.occlusionState.contains(.visible)), appHidden=\(NSApp.isHidden), frame=\(window.frame), collectionBehavior=\(window.collectionBehavior.rawValue)")
        scheduleTipClose(after: duration)
    }

    func dismissTipWindow(releaseResources: Bool) {
        tipCloseWorkItem?.cancel()
        tipCloseWorkItem = nil
        tipDismissWorkItem?.cancel()
        tipDismissWorkItem = nil

        guard let tipWindow else {
            if releaseResources {
                tipModel = nil
            }
            return
        }

        let cleanup = { [weak self] in
            guard let self else { return }
            if releaseResources {
                self.tipWindow?.close()
                self.tipWindow = nil
                self.tipModel = nil
            } else {
                tipWindow.orderOut(nil)
            }
        }

        let shouldAnimateOut = tipDismissAnimationDuration > 0 && (tipModel?.isVisible ?? false)
        tipModel?.dismiss()

        guard shouldAnimateOut else {
            cleanup()
            return
        }

        let workItem = DispatchWorkItem(block: cleanup)
        tipDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + tipDismissAnimationDuration,
            execute: workItem
        )
    }

    func scheduleTipClose(after duration: TimeInterval) {
        tipCloseWorkItem?.cancel()
        tipCloseWorkItem = nil

        guard duration > 0 else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissTipWindow(releaseResources: false)
        }
        tipCloseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    /// 创建携带目标应用信息的提示窗口，后续提示复用同一非激活面板。
    func ensureTipWindow(prompt: QuitPrompt, duration: TimeInterval, application: TipApplication?) -> TipPanel {
        if let tipWindow {
            return tipWindow
        }

        let model = TipOverlayModel(
            presentation: TipPresentation(
                prompt: prompt,
                duration: duration,
                application: application
            )
        )
        let hostingController = NSHostingController(rootView: TipView(model: model))
        let window = TipPanel(
            contentRect: CGRect(origin: .zero, size: tipWindowSize)
        )

        window.contentViewController = hostingController

        tipModel = model
        tipWindow = window
        return window
    }

    /// 在目标屏幕可见区域居中，保持现有提示尺寸与非激活行为。
    func positionTipWindow(_ window: NSWindow, screen: NSScreen?) {
        guard let screen else { return }

        let visibleFrame = screen.visibleFrame
        let origin = CGPoint(
            x: visibleFrame.midX - (tipWindowSize.width / 2),
            y: visibleFrame.midY - (tipWindowSize.height / 2)
        )

        window.setFrame(
            CGRect(origin: origin, size: tipWindowSize),
            display: true
        )
    }
}
