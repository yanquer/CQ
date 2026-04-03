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

final class EventTapController {
    private let config: QuitGuardConfig
    private let handler: EventHandler
    private let tipAnimationDuration: TimeInterval = 0.18

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tipWindow: TipPanel?
    private var tipModel: TipOverlayModel?
    private var tipCloseWorkItem: DispatchWorkItem?
    private var tipDismissWorkItem: DispatchWorkItem?

    init(config: QuitGuardConfig, handler: EventHandler) {
        self.config = config
        self.handler = handler
    }

    func start() {
        if tap != nil {
            enableTap()
            return
        }

        createTap()
    }

    func stop() {
        handler.resetRuntimeState()
        destroyTipWindow()
        removeTap()
    }

    func refresh() {
        stop()
        start()
    }

    private func createTap() {
        let callback = EventTapController.tapCallback
        let ref = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: makeEventMask(),
            callback: callback,
            userInfo: ref
        )

        guard let tap else {
            AppLog.info("创建 event tap 失败")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let runLoopSource else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        enableTap()
    }

    private func handle(event: CGEvent, eventType: CGEventType) -> Unmanaged<CGEvent>? {
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            recoverTap(eventType)
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

    private func recoverTap(_ eventType: CGEventType) {
        AppLog.info("event tap 已停用: \(eventType.rawValue)")
        // 休眠唤醒后系统可能直接停用 tap，直接重建会比单纯 enable 更稳。
        DispatchQueue.main.async { [weak self] in
            self?.refresh()
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
