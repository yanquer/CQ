//
//  Item.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
