//
//  OpenAccess.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation
import Cocoa

extension AppDelegate {
    static let openAccessSymbol = "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'"
    
    static func openAccessSettings(){
        _ = ShellCommand.exec(cmds: ["-c", openAccessSymbol])
    }
    
    static func hasAccessAndGain() -> Bool{
        if AXIsProcessTrusted(){ return true }
        
        openAccessSettings()
        restartCQ()
        
        return false
    }
    
    static func restartCQ(){
        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-b", Bundle.main.bundleIdentifier!])
        NSApp.terminate(self)
    }
}
