//
//  AppDelegate.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation
import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    private let config = QuitGuardConfig.shared
    private let state = QuitGuardState()
    let menuPopoverController = MenuPopoverController()
    private var workspaceObservers: [NSObjectProtocol] = []

    private lazy var eventHandler = EventHandler(
        config: config,
        state: state,
        isBlockedApp: { AppBlack.this.isCurrentAppBlocked() }
    )

    private lazy var eventTapController = EventTapController(
        config: config,
        handler: eventHandler
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AppDelegate.hasAccess() {
            #if DEBUG
            AppLog.info("可能没有获取到辅助权限, 确认后请清理后手动获取")
            #else
            let _ = NoAccessView().openInWindow(title: "CQ请求授权", sender: self)
            #endif
        }

        AppBlack.this.startObservingWorkspace()
        registerWorkspaceNotifications()
        eventTapController.start()
        makeMenuButton()
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeWorkspaceNotifications()
        AppBlack.this.stopObservingWorkspace()
        eventTapController.stop()
    }
}

extension AppDelegate {
    private func registerWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        let willSleep = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillSleep()
        }

        let didWake = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidWake()
        }

        workspaceObservers = [willSleep, didWake]
    }

    private func removeWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers.removeAll()
    }

    private func handleWillSleep() {
        AppLog.info("系统即将休眠，暂停事件拦截")
        eventTapController.stop()
    }

    private func handleDidWake() {
        AppLog.info("系统已唤醒，重建事件拦截")
        AppBlack.this.refreshCurrentAppPath()
        eventTapController.refresh()
    }
}
