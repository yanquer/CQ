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

import Cocoa
import ServiceManagement
import UserNotifications


class AutoLaunch {

    
    
    private static let id = "\(Bundle.main.bundleIdentifier!).LaunchAtLogin"
    // private static let loginItem = SMAppService.loginItem(identifier: id)
    private static let loginItem = SMAppService.mainApp
    
    static var isEnabledAutoLaunch: Bool{
        return loginItem.status == SMAppService.Status.enabled
    }
    
    static func enableAutoLaunch() {
        if (!isEnabledAutoLaunch) {
            do {
                try loginItem.register()
            } catch {
                print("注册失败")
            }
        }
    }
    
    static func disableAutoLaunch() {
        if (isEnabledAutoLaunch) {
            do {
                try loginItem.unregister()
            } catch {
                print("取消注册失败")
            }
        }
    }

    
}

