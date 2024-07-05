//
//  CreateEventTap.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//
//  创建事件截取
//

import Foundation
import AppKit


extension AppDelegate {
    
    static let interestEventType = (1 << NSEvent.EventType.keyDown.rawValue) | (1 << NSEvent.EventType.keyUp.rawValue)
    
    static func createEventTap(){
        if let tapEvent = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(interestEventType),
            callback: { (proxy, cgEventType, cgEvent, ctx) -> Unmanaged<CGEvent>? in
        
                // if let _info = ctx?.load(as: EventInfo.self) {}
                if (ctx != nil){
                    if EventHandler.eventPass(
                        event: cgEvent,
                        eventType: cgEventType,
                        infoPointer: ctx,
                        proxy: proxy){
                        // AppLog.info("成功触发eventPass但是没有comdq")
                        return .passUnretained(cgEvent)
                    } else {
                        // AppLog.info("comdq")
                        return nil
                    }
                }
                // AppLog.info("===半成功触发handle")
                // 底层自己回收
                return .passUnretained(cgEvent)
            },
            // userInfo: &info
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(info).toOpaque())
        ){
            
            RunLoop.current.add(tapEvent, forMode: .common)
            CGEvent.tapEnable(tap: tapEvent, enable: true)
        } else {
            
            AppLog.info("创建event tap失败")
        }
    }

    
}


