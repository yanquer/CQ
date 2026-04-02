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

final class EventTapController {
    private let config: QuitGuardConfig
    private let handler: EventHandler

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tipWindow: NSWindow?

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
        closeTipWindow()
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

    private func presentTip(_ prompt: String, duration: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            self?.tipWindow?.close()
            self?.tipWindow = TipView(alertText: prompt)
                .showViewOnNewWindowInSpecificTime(during: CGFloat(duration))
        }
    }

    private func closeTipWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.tipWindow?.close()
            self?.tipWindow = nil
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
