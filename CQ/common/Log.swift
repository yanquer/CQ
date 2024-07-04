//
//  Log.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation
import os.log

struct AppLog{
    static func info(_ data: String){
        os_log(.info, "\(data)")
    }
    
    static func debug(_ data: String){
        os_log(.debug, "\(data)")
    }
    
    static func error(_ data: String){
        os_log(.error, "\(data)")
    }
}


