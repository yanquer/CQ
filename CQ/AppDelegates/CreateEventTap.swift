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

private final class TipPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
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
    private let strategies: [EventTapStrategy]
    private let tipAnimationDuration: TimeInterval = 0.18

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tipWindow: TipPanel?
    private var tipModel: TipOverlayModel?
    private var tipCloseWorkItem: DispatchWorkItem?
    private var tipDismissWorkItem: DispatchWorkItem?

    private(set) var currentTapSnapshot: TapSnapshot = .idle

    init(
        config: QuitGuardConfig,
        handler: EventHandler,
        statusHandler: @escaping (QuitGuardRuntimeStatus) -> Void = { _ in },
        strategies: [EventTapStrategy] = EventTapStrategy.defaultStrategies,
        tapCreator: @escaping EventTapCreator = EventTapController.defaultTapCreator
    ) {
        self.config = config
        self.handler = handler
        self.statusHandler = statusHandler
        self.strategies = strategies
        self.tapCreator = tapCreator
    }

    /// 启动事件拦截，并返回当前是否已经成功建立 tap。
    /// - Returns: 事件拦截是否可用。
    func start() -> Bool {
        if tap != nil {
            AppLog.info("event tap 已存在，直接尝试启用")
            enableTap()
            return currentTapSnapshot.isEnabled
        }

        AppLog.info("开始创建 event tap")
        return createTap()
    }

    func stop() {
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
        enableTap()
        AppLog.info("event tap 创建成功并已加入主运行循环")
        return true
    }

    private func handle(event: CGEvent, eventType: CGEventType) -> Unmanaged<CGEvent>? {
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            handleTapDisabled(eventType)
            return .passUnretained(event)
        }

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

    private func presentTip(_ prompt: QuitPrompt, duration: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            self?.presentTipOnMainThread(prompt, duration: duration)
        }
    }

    private func closeTipWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.dismissTipWindow(releaseResources: false)
        }
    }

    private func destroyTipWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.dismissTipWindow(releaseResources: true)
        }
    }

    /// 处理系统停用 event tap 的恢复流程，并把结果写回运行状态。
    /// - Parameter eventType: 系统返回的停用事件类型。
    func handleTapDisabled(_ eventType: CGEventType) {
        AppLog.info("event tap 已停用: \(eventType.rawValue)")
        markTapDisabled()
        statusHandler(.tapDisabled)
        // 休眠唤醒后系统可能直接停用 tap，直接重建会比单纯 enable 更稳。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.refresh() {
                AppLog.info("event tap 恢复成功")
                self.statusHandler(.ready)
            } else {
                AppLog.error("event tap 恢复失败")
            }
        }
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

    private func enableTap() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        currentTapSnapshot = makeTapSnapshot(
            location: currentTapSnapshot.currentLocation,
            option: currentTapSnapshot.currentOption,
            isEnabled: true,
            failureReason: nil,
            attempts: currentTapSnapshot.attempts
        )
        AppLog.info("event tap 已启用")
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

    var currentTipScreen: NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }

    func presentTipOnMainThread(_ prompt: QuitPrompt, duration: TimeInterval) {
        tipDismissWorkItem?.cancel()

        let window = ensureTipWindow(prompt: prompt, duration: duration)
        positionTipWindow(window)
        window.alphaValue = 1
        window.orderFrontRegardless()

        let shouldAnimateIn = !(tipModel?.isVisible ?? false)
        tipModel?.present(
            prompt: prompt,
            duration: duration,
            animateIn: shouldAnimateIn
        )
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

    func ensureTipWindow(prompt: QuitPrompt, duration: TimeInterval) -> TipPanel {
        if let tipWindow {
            return tipWindow
        }

        let model = TipOverlayModel(
            presentation: TipPresentation(
                prompt: prompt,
                duration: duration
            )
        )
        let hostingController = NSHostingController(rootView: TipView(model: model))
        let window = TipPanel(
            contentRect: CGRect(origin: .zero, size: tipWindowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        configureTipWindow(window)

        tipModel = model
        tipWindow = window
        return window
    }

    func configureTipWindow(_ window: TipPanel) {
        window.level = .mainMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isMovable = false
        window.hidesOnDeactivate = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
    }

    func positionTipWindow(_ window: NSWindow) {
        guard let screen = currentTipScreen else { return }

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
