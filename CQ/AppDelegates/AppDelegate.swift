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
    var statusItem: NSStatusItem?
    var popOver = NSPopover()
    static var info = EventInfo.currentEventInfo()
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 不要自动获取, 不然有的用户看不懂为啥弹出个设置
        // if AppDelegate.hasAccessAndGain(){
        //     AppLog.info("已获取辅助功能权限")
        // }
        
        if !AppDelegate.hasAccess(){
            #if DEBUG
            AppLog.info("可能没有获取到辅助权限, 确认后请清理后手动获取")
            #else
            // 打开请求辅助权限窗口
            let _ = NoAccessView().openInWindow(title: "CQ请求授权", sender: self)
            #endif
        }
            
        AppDelegate.createEventTap()
        
        makeMenuButton()
    }
    
}


