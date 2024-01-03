//
//  OpenAccess.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//
// 打开辅助功能
//

import Foundation
import Cocoa

extension AppDelegate {
    static let openAccessSymbol = "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'"
    
    static func openAccessSettings(){
        _ = ShellCommand.exec(cmds: ["-c", openAccessSymbol])
    }
    
    static func hasAccess() -> Bool{
        return AXIsProcessTrusted()
    }
    
    static func hasAccessAndGain() -> Bool{
        // 自动尝试获取, 有个bug, 就是不能一直 restartCQ
        if AXIsProcessTrusted(){ return true }
        
        openAccessSettings()
        // restartCQ()
        
        return false
    }
    
    static func restartCQ(){
        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-b", Bundle.main.bundleIdentifier!])
        NSApp.terminate(self)
    }
}
