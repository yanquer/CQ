//
//  BaseView.swift
//  CQ
//
//  Created by 烟雀 on 2024/1/1.
//

import Foundation
import SwiftUI

extension TipView{
    
    // MARK: - Interface
    
    func showViewOnNewWindowInSpecificTime(during timer: CGFloat) -> NSWindow {
        let alertWindow = self.setWindow()
        displayAsAlert(win: alertWindow, Timer: timer)
        return alertWindow
    }
    
    
    // MARK: - Attribute
    
    private func displayAsAlert(win:NSWindow, Timer:Double) {
        
        // 在当前窗口上显示
        win.level = .popUpMenu
        
        // 设置透明
        // win.isOpaque = false
        // win.backgroundColor = NSColor.clear
        // win.hasShadow = false  // 可选：如果不想要窗口阴影
        // win.alphaValue = 0.1
        
        win.isMovableByWindowBackground = false
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isOpaque = false
        win.styleMask.remove(.closable)
        win.styleMask.remove(.fullScreen)
        win.styleMask.remove(.miniaturizable)
        win.styleMask.remove(.fullSizeContentView)
        win.styleMask.remove(.resizable)
        win.backgroundColor = NSColor.clear
        win.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + Timer) {
            win.close()
        }
    }
    
    private func setWindow() -> NSWindow {
        NSWindow(contentViewController: NSHostingController(rootView: self))
    }
}





