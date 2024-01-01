//
//  EventInfo.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation

class EventInfo{
    
    var alertStr: String?
    var touchTime: Int = 0
    
    func reset(){
        self.touchTime = 0
    }

    func setOneTouch(timer: Double=3){
        // 在 timer 秒内不再次点击, 就重置
        self.touchTime = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + timer) {
            self.touchTime = 0
        }
    }
    
    
    static private var _infoObj: EventInfo?
    static func currentEventInfo() -> EventInfo{
        
        if ((EventInfo._infoObj == nil)){
            EventInfo._infoObj = EventInfo()
        }
        
        return EventInfo._infoObj!
    }
    
    // settings
    var dobulueClickTime: Int = 3
    var alterWinCloseTime: Int = 3
    
}


