//
//  MenuButton.swift
//  CQ
//
//  Created by 烟雀 on 2024/1/2.
//

import Foundation
import SwiftUI

extension AppDelegate{
    
    func makeMenuButton() {
        popOver.behavior = .transient
        popOver.animates = true
        popOver.contentViewController = NSViewController()
        popOver.contentViewController?.view = NSHostingView(rootView: MenuView())
        popOver.contentSize = NSSize(width: 360, height: 800)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let menuButton = statusItem?.button{
            menuButton.image = NSImage(named: "icon")
            menuButton.image?.isTemplate = true  // change image color to surrounding environment
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
