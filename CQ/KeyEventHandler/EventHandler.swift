//
//  EventHandler.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation
import AppKit


class EventHandler{
    
    static func handle(event: NSEvent, cgEvent: CGEvent, info: EventInfo?, proxy: CGEventTapProxy) -> CGEvent? {
        
        let keyCode = event.keyCode
        let flag = event.modifierFlags
        
        if event.type == .keyDown && keyCode == 12 && flag.contains(.command){
            print("command + q, trriggle")
            
            // todo: 触发一个view, 比如超时Dialog动画, 动画时间内结束就返回空, 表示拦截这个事件
            return nil
        }
        
        return cgEvent
    }
    
    
}

