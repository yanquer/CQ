//
//  MenuButton.swift
//  CQ
//
//  Created by 烟雀 on 2024/1/2.
//
// 状态栏菜单
//

import Foundation
import SwiftUI

extension AppDelegate{
    
    func makeMenuButton() {
        popOver.behavior = .transient
        popOver.animates = true
        popOver.contentViewController = NSHostingController(rootView: MenuShowView())
        popOver.contentSize = NSSize(
            width: MenuPanelStyle.popoverWidth,
            height: MenuPanelStyle.popoverHeight
        )
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureMenuButton()
    }
    
    @objc func MenuButtonToggle(sender: AnyObject) {
        if popOver.isShown{
            popOver.performClose(sender)
            return
        }

        guard let button = statusItem?.button else { return }
        popOver.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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
        menuButton.target = self
        menuButton.action = #selector(MenuButtonToggle)
    }
}
