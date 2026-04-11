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
        CGEventTapCallBack,
        UnsafeMutableRawPointer?,
        CGEventMask
    ) -> CFMachPort?

    private let config: QuitGuardConfig
    private let handler: EventHandler
    private let statusHandler: (QuitGuardRuntimeStatus) -> Void
    private let tapCreator: EventTapCreator
    private let tipAnimationDuration: TimeInterval = 0.18

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tipWindow: TipPanel?
    private var tipModel: TipOverlayModel?
    private var tipCloseWorkItem: DispatchWorkItem?
    private var tipDismissWorkItem: DispatchWorkItem?

    init(
        config: QuitGuardConfig,
        handler: EventHandler,
        statusHandler: @escaping (QuitGuardRuntimeStatus) -> Void = { _ in },
        tapCreator: @escaping EventTapCreator = EventTapController.defaultTapCreator
    ) {
        self.config = config
        self.handler = handler
        self.statusHandler = statusHandler
        self.tapCreator = tapCreator
    }

    /// 启动事件拦截，并返回当前是否已经成功建立 tap。
    /// - Returns: 事件拦截是否可用。
    func start() -> Bool {
        if tap != nil {
            AppLog.info("event tap 已存在，直接尝试启用")
            enableTap()
            return true
        }

        AppLog.info("开始创建 event tap")
        return createTap()
    }

    func stop() {
        AppLog.info("停止 event tap 并清理运行态")
        handler.resetRuntimeState()
        destroyTipWindow()
        removeTap()
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
        tap = tapCreator(callback, ref, makeEventMask())

        guard let tap else {
            AppLog.info("创建 event tap 失败")
            statusHandler(.tapCreateFailed)
            return false
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let runLoopSource else {
            AppLog.info("创建 event tap run loop source 失败")
            removeTap()
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
        AppLog.info("event tap 已启用")
    }

    /// 构造默认的系统级 event tap 创建逻辑。
    /// - Parameters:
    ///   - callback: event tap 回调。
    ///   - userInfo: 回调透传上下文。
    ///   - eventMask: 需要监听的事件掩码。
    /// - Returns: 系统返回的 event tap 端口。
    private static func defaultTapCreator(
        callback: @escaping CGEventTapCallBack,
        userInfo: UnsafeMutableRawPointer?,
        eventMask: CGEventMask
    ) -> CFMachPort? {
        CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
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
