//
//  BaseView.swift
//  CQ
//
//  Created by 烟雀 on 2024/1/1.
//

import Foundation
import SwiftUI


extension View{
    
    // MARK: - Interface
    
    func showViewOnNewWindow(title: String) -> NSWindow {
        let alertWindow = self.setWindow()
        displayAsMainWin(win: alertWindow, title: title)
        return alertWindow
    }
    
    func showViewOnNewWindowInSpecificTime(during timer: CGFloat) -> NSWindow {
        let alertWindow = self.setWindow()
        displayAsAlert(win: alertWindow, timer: timer)
        return alertWindow
    }
    
    private func setCommonWinAttr(win: NSWindow){
        win.isMovableByWindowBackground = true
        // 控件头 透明
        win.titlebarAppearsTransparent = true
        // 允许在所有桌面空间
        win.collectionBehavior = .canJoinAllSpaces
        // 不透明
        win.isOpaque = false
        win.styleMask.remove(.fullScreen)
        win.styleMask.remove(.miniaturizable)
        win.styleMask.remove(.fullSizeContentView)
        win.styleMask.remove(.resizable)
        win.backgroundColor = NSColor.clear
        win.orderFrontRegardless()
    }
    
    private func displayAsMainWin(win: NSWindow, title: String) {
        
        // 在当前窗口上显示
        // win.level = .floating
        
        self.setCommonWinAttr(win: win)
        
        win.title = title
        
        win.backgroundColor = AppColor.mainBgColorNS
        // 不透明
        win.isOpaque = true
        
    }
    
    // MARK: - Attribute
    
    private func displayAsAlert(win: NSWindow, timer:Double=0) {
        
        // 在当前窗口上显示
        // win.level = .floating
    
        // 设置透明
        // win.isOpaque = false
        // win.backgroundColor = NSColor.clear
        // win.hasShadow = false  // 可选：如果不想要窗口阴影
        // win.alphaValue = 0.1
        
        self.setCommonWinAttr(win: win)
        win.isMovableByWindowBackground = false
        win.titleVisibility = .hidden
        win.styleMask.remove(.closable)

        
        if (timer != 0){
            DispatchQueue.main.asyncAfter(deadline: .now() + timer) {
                win.close()
            }
        }
    }
    
    private func setWindow() -> NSWindow {
        NSWindow(contentViewController: NSHostingController(rootView: self))
    }
    
}







