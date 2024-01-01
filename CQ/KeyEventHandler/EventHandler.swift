//
//  EventHandler.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation
import AppKit


class EventHandler{
    
    static var _tipView: NSWindow?
    
    static func eventPass(event: CGEvent, eventType: CGEventType, info: EventInfo?, proxy: CGEventTapProxy) -> Bool {
        
        print(eventType.self, eventType.rawValue)
        
        switch eventType {
        case .keyDown:
            return eventKeyDown(event: event, info: info)
        case .keyUp:
            return eventKeyUp(event: event, info: info)
        default:
            return true
        }
        
    }
    
    static func eventKeyIsCommandQ(event: CGEvent) -> Bool{
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        print(keyCode, "+" ,flags)
        if keyCode == 12 && flags.contains(.maskCommand) {return true}
        
        return false
    }
    
    static func eventKeyDown(event: CGEvent, info: EventInfo?) -> Bool{
        if eventKeyIsCommandQ(event: event){
            print("command + q down, trriggle")
            
            if (info?.touchTime==0){
                info?.setOneTouch(timer: Double(info?.dobulueClickTime ?? 3))
//                info?.alertStr = "请再点击一次cmd + q以退出"
                self._tipView?.close()
                _tipView = TipView(alertText: "请再点击一次 CMD+Q 以退出").showViewOnNewWindowInSpecificTime(during: CGFloat(info?.alterWinCloseTime ?? 3))
            } else if (info?.touchTime==1) {
                info?.reset()
                self._tipView?.close()
                return true
            }
            
            return false
        }
        return true
    }
    
    static func eventKeyUp(event: CGEvent, info: EventInfo?) -> Bool{
        if eventKeyIsCommandQ(event: event){
            print("command + q up, trriggle")
            
            // todo: 触发一个view, 比如超时Dialog动画, 动画时间内结束就返回空, 表示拦截这个事件
            return false
        }
        return true
        
    }
    

}

