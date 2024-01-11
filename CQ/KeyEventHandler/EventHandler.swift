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
        
        // print(eventType.self, eventType.rawValue)
        
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
        // 如果很快按下, 这个会检测不到, 因为Mac貌似默认会认为快速点击为按下
        // 导致 flags 变成 CGEventFlags(rawValue: 256)
        // 手动判断一下轻按也当作抬起处理
        return isCmdQ(keyCode: keyCode, flags: flags) || isCmdQEnter(keyCode: keyCode, flags: flags)
    }
    
    static func isCmdQ(keyCode: Int64, flags: CGEventFlags) -> Bool{
        return keyCode == 12 && flags.contains(.maskCommand)
    }
    
    static func isCmdQEnter(keyCode: Int64, flags: CGEventFlags) -> Bool{
        // 很快按下的时候, 抬起的时候修饰键会变成 256, 表示是一个很快按下的操作
        return keyCode == 12 && flags.contains(CGEventFlags(rawValue: 256))
    }
    
    static let _initEnterFlag = -1.0
    static var firstEnterTime = _initEnterFlag
    static func eventKeyDown(event: CGEvent, info: EventInfo?) -> Bool{
        if eventKeyIsCommandQ(event: event){
            print("command + q down, trriggle")
            if (firstEnterTime == _initEnterFlag){
                firstEnterTime = NSDate().timeIntervalSince1970 * 1000
            }
            
            let now = NSDate().timeIntervalSince1970 * 1000
            // 间隔时间小于300ms, 说明是长按事件, 跳过
            print("====s=====>")
            print("====s=====>")
            print(now)
            print(firstEnterTime)
            print(now - firstEnterTime)
            print("====n=====>")
            print("====n=====>")
            if (firstEnterTime == _initEnterFlag){
                firstEnterTime = now
            } else if (now - firstEnterTime < 300){
                print("长按事件, 跳过")
                firstEnterTime = now
                return true
            }
            
            // 把 cmd + q 给拦截了
            if (info?.touchTime==0){
                info?.setOneTouch(timer: Double(info?.dobulueClickTime ?? 3))
                // info?.alertStr = "请再点击一次cmd + q以退出"
                self._tipView?.close()
                _tipView = TipView(alertText: "请再点击一次 CMD+Q 以退出").showViewOnNewWindowInSpecificTime(during: CGFloat(info?.alterWinCloseTime ?? 3))
            } else if (info?.touchTime==1) {
                info?.reset()
                self._tipView?.close()
                print("允许正常退出")
                return true
            }
            
            return false
        }
        return true
    }
    
    static func eventKeyUp(event: CGEvent, info: EventInfo?) -> Bool{
        if eventKeyIsCommandQ(event: event){
            print("command + q up, trriggle")
            firstEnterTime = _initEnterFlag
            return true
            
            // todo: 触发一个view, 比如超时Dialog动画, 动画时间内结束就返回空, 表示拦截这个事件
            // return false
        }
        return true
        
    }
    

}

