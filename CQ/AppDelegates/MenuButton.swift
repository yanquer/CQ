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
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: menuButtonEventMask) { [weak self] event in
            self?.handleLocalClick(event) ?? event
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

    func handleLocalClick(_ event: NSEvent) -> NSEvent {
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
        MenuPopoverInteraction.shouldClose(
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
    func makeMenuButton() {
        menuPopoverController.configure(
            contentViewController: NSHostingController(rootView: MenuShowView()),
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

    @objc func MenuButtonToggle(sender: AnyObject) {
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
