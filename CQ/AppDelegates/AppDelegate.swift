//
//  AppDelegate.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation
import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    static var info = EventInfo.currentEventInfo()
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 其实不用, 自己写获取方式, 因为会自动触发
//        if AppDelegate.hasAccessAndGain(){
//            print("已获取辅助功能权限")
//        }
        AppDelegate.createEventTap()
        
        
        // 显示状态栏
//        NSApplication.shared.presentationOptions.insert(.autoHideMenuBar)
        self.setStatusBar()
    }
    
    
    var statusBarItem: NSStatusItem?
    func setStatusBar(){
        // 创建状态栏项目
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // 设置状态栏项目的外观
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: nil)
            button.action = #selector(togglePopover(_:))
        }
    }
    
    var popover: NSPopover?
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover == nil {
            // 创建并显示 NSPopover
            popover = NSPopover()
            popover?.contentViewController = NSHostingController(rootView: SettingFormView())
            popover?.show(relativeTo: statusBarItem!.button!.bounds, of: statusBarItem!.button!, preferredEdge: .minY)
        } else {
            // 隐藏 NSPopover
            popover?.performClose(sender)
            popover = nil
        }
    }

    
}


