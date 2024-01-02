//
//  NoAccessView.swift
//  CQ
//
//  Created by 烟雀 on 2024/1/2.
//

import Foundation
import SwiftUI

struct NoAccessView: View{
    
    var body: some View{
        
        VStack{
            
            Text("当 `在设置授权辅助功能后`, 点击 `重启`").multilineTextAlignment(.center)
            
            Button("打开设置", action: {
                AppDelegate.openAccessSettings()
            }).padding(.top, 15.0)
                .padding(.bottom, 7.0)
                .frame(alignment: .leading)
            
            Button("重启", action: {
                AppDelegate.restartCQ()
            }).padding(.top, 8.0)
                .padding(.bottom, 10.0)
                .frame(alignment: .leading)
        }.frame(width: 300, height: 300)
        
    }
}

extension NoAccessView {
    
    func openInWindow(title: String, sender: Any?) -> NSWindow {
        let win = NSWindow(contentViewController: NSHostingController(rootView: self))
        win.title = title
        win.makeKeyAndOrderFront(sender)
        win.orderFrontRegardless()
        return win
    }
}



