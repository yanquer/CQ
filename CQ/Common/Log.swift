//
//  Log.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation
import os.log

struct AppLog{
    static let logCq = OSLog(subsystem: "com.yq.cq", category: "util")
    
    static func info(_ data: String){
        os_log("%{public}@", log: logCq, type: .info, data)
    }
    
    static func debug(_ data: String){
        os_log("%{public}@", log: logCq, type: .debug, data)
    }
    
    static func error(_ data: String){
        os_log("%{public}@", log: logCq, type: .error, data)
    }
}

