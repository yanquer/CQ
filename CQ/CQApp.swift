//
//  CQApp.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import SwiftUI
import SwiftData

@main
struct CQApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        Settings {
            VStack{
                SettingFormView().frame(width: 300, height: 200).padding(10)
            }
        }
    }
}
