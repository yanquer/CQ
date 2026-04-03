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
        popOver.contentViewController = NSViewController()
        popOver.contentViewController?.view = NSHostingView(rootView: MenuShowView())
        popOver.contentSize = NSSize(width: 360, height: 800)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let menuButton = statusItem?.button,
           let image = NSImage(named: "icon") {
            image.isTemplate = false
            image.size = NSSize(width: 16, height: 16)
            menuButton.image = image
            menuButton.imagePosition = .imageOnly
            menuButton.title = ""
            menuButton.action = #selector(MenuButtonToggle)
        }
    }
    
    @objc func MenuButtonToggle(sender: AnyObject) {
        //      showing popover
        if popOver.isShown{
            popOver.performClose(sender)
        }else{
            //Top Get Button Location for popover arrow
            self.popOver.show(relativeTo: (statusItem?.button!.bounds)!, of: (statusItem?.button!)!, preferredEdge: NSRectEdge.minY)
        }
    }
}
