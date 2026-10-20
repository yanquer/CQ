//
//  MenuButton.swift
//  CQ
//
//  Created by 烟雀 on 2024/1/2.
import AppKit
import SwiftUI

let menuButtonEventMask: NSEvent.EventTypeMask = [.leftMouseUp, .rightMouseUp]

struct MenuPopoverInteraction {
    static func shouldClose(
        at point: NSPoint,
        popoverFrame: NSRect,
        buttonFrame: NSRect
    ) -> Bool {
        !buttonFrame.contains(point) && !popoverFrame.contains(point)
    }
}

final class MenuPopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private weak var statusButton: NSStatusBarButton?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    override init() {
        super.init()
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.delegate = self
    }

    func configure(contentViewController: NSViewController, size: NSSize) {
        popover.contentViewController = contentViewController
        popover.contentSize = size
    }

    func attach(statusItem: NSStatusItem) {
        statusButton = statusItem.button
    }

    func toggle(sender: AnyObject?) {
        popover.isShown ? close(sender) : show()
    }

    func close(_ sender: AnyObject? = nil) {
        popover.performClose(sender)
        removeClickMonitors()
    }

    func popoverDidClose(_ notification: Notification) {
        removeClickMonitors()
    }
}

private extension MenuPopoverController {
    func show() {
        guard let statusButton else { return }
        popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
        installClickMonitors()
    }

    func installClickMonitors() {
        guard localMonitor == nil, globalMonitor == nil else { return }
        // 同时监听应用内外点击，保证菜单弹层都能及时收起。
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [menuButtonEventMask, .keyDown]) { [weak self] event in
            guard let self else { return event }
            return self.handleLocalEvent(event)
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: menuButtonEventMask) { [weak self] _ in
            self?.handleGlobalClick()
        }
    }

    func removeClickMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    /// 处理弹层点击和 Escape，选择器打开时将键盘交给系统模态窗口。
    func handleLocalEvent(_ event: NSEvent) -> NSEvent? {
        if event.type == .keyDown {
            let window = popover.contentViewController?.view.window
            if event.keyCode == 53, event.window === window, window?.attachedSheet == nil {
                close()
                return nil
            }
            return event
        }
        if shouldClosePopover(at: screenPoint(for: event)) {
            close()
        }
        return event
    }

    func handleGlobalClick() {
        if shouldClosePopover(at: NSEvent.mouseLocation) {
            close()
        }
    }

    func shouldClosePopover(at point: NSPoint) -> Bool {
        // 系统选择器关闭前保留其父弹层，避免点击选择器时连带销毁父窗口。
        guard popover.contentViewController?.view.window?.attachedSheet == nil else { return false }
        return MenuPopoverInteraction.shouldClose(
            at: point,
            popoverFrame: popoverFrame,
            buttonFrame: buttonFrame
        )
    }

    func screenPoint(for event: NSEvent) -> NSPoint {
        guard let window = event.window else { return NSEvent.mouseLocation }
        return window.convertPoint(toScreen: event.locationInWindow)
    }

    var popoverFrame: NSRect {
        popover.contentViewController?.view.window?.frame ?? .zero
    }

    var buttonFrame: NSRect {
        guard let statusButton, let window = statusButton.window else { return .zero }
        let frame = statusButton.convert(statusButton.bounds, to: nil)
        return window.convertToScreen(frame)
    }
}

extension AppDelegate {
    /// 创建菜单栏入口，并让面板展示实际保护状态及恢复操作。
    @MainActor
    func makeMenuButton() {
        menuPopoverController.configure(
            contentViewController: NSHostingController(rootView: MenuShowView(model: makeMenuPanelModel())),
            size: NSSize(
                width: MenuPanelStyle.popoverWidth,
                height: MenuPanelStyle.popoverHeight
            )
        )
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let statusItem {
            menuPopoverController.attach(statusItem: statusItem)
        }
        configureMenuButton()
    }

    /// 打开菜单前同步权限，避免展示已失效的授权状态。
    @MainActor
    @objc func MenuButtonToggle(sender: AnyObject) {
        refreshPermissionsIfNeeded()
        makeMenuPanelModel().refreshAutoLaunchStatus()
        menuPopoverController.toggle(sender: sender)
    }
}

private extension AppDelegate {
    func configureMenuButton() {
        guard let menuButton = statusItem?.button,
              let image = NSImage(named: "icon") else { return }

        image.isTemplate = false
        image.size = NSSize(width: 16, height: 16)
        menuButton.image = image
        menuButton.imagePosition = .imageOnly
        menuButton.title = ""
        menuButton.sendAction(on: menuButtonEventMask)
        menuButton.target = self
        menuButton.action = #selector(MenuButtonToggle)
    }
}
