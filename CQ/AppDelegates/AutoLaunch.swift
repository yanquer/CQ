//
//  AutoLaunch.swift
//  CQ
//
//  Created by 烟雀 on 2024/1/3.
//
//  支持开机自启
//

import Foundation
import SwiftUI


extension AppDelegate{
    static func enableAutoLaunch() {
        let launcherAppIdentifier = Bundle.main.bundleIdentifier!

//        if !isAutoLaunchEnabled() {
//            SMLoginItemSetEnabled(launcherAppIdentifier as CFString, true)
//        }
    }
}

