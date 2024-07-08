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

        win.level = .mainMenu
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .fullScreenPrimary]
        win.isRestorable = true
        
        self.setToFocusWin(win: win)
        
        if (timer != 0){
            DispatchQueue.main.asyncAfter(deadline: .now() + timer) {
                win.close()
            }
        }
    }
    
    internal func setToFocusWin(win: NSWindow){
        if let foucsScreen = self.currentScreen{
            win.setFrame(foucsScreen.visibleFrame, display: true)
            
            // 设置窗口的位置,使其在屏幕中心
            // win.setFrameOrigin(NSPoint(x: foucsScreen.visibleFrame.midX,
            //                             y: foucsScreen.visibleFrame.midY))
            let _sizeX = TipViewSize.width
            let _sizeY = TipViewSize.height
            win.setFrameOrigin(NSPoint(x: foucsScreen.visibleFrame.midX - (_sizeX / 2),
                                       y: foucsScreen.visibleFrame.midY - (_sizeY / 2)))
        }
    }
    
    internal var currentScreen: NSScreen? {
        // return NSScreen.main
        
        // if let keyWindow = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
        // if let keyWindow = NSApplication.shared.keyWindow {
        //    return NSScreen.screens.first { $0.frame.contains(keyWindow.frame.origin) }
        // }
        // return nil
        
        // 虽然API说的是, 使用 NSScreen.main 可以获取当前焦点窗口,
        // 但是, 多显示器时, 当在副显示器的全屏APP且焦点在此APP时, 使用mian获取到的是主显示器的窗口,
        //  其他方式 keyWindow 啥的获取到的是 nil
        // 所以暂时曲线救国一下,
        //  判断鼠标所在的显示器,
        return NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
    }
    
    private func setWindow() -> NSWindow {
        NSWindow(contentViewController: NSHostingController(rootView: self))
    }
    
}







