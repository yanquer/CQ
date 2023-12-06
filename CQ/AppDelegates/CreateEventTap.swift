//
//  CreateEventTap.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation
import AppKit


extension AppDelegate {
    
    static func createEventTap(){
        let tapEvent = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(kAEKeyDown),
            callback: { proxy, cgEventType, cgEvent, ctx in
                let _info = ctx?.load(as: EventInfo.self)
                if let nsEvent = NSEvent(cgEvent: cgEvent){
                    if let newEvent = EventHandler.handle(
                        event: nsEvent,
                        cgEvent: cgEvent,
                        info: _info,
                        proxy: proxy){
                        
                        return .passUnretained(newEvent)
                    }
                
                }
                
                return .passUnretained(cgEvent)
            },
            userInfo: &info)
    }
    
}


