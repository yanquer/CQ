//
//  SettingFormView.swift
//  CQ
//
//  Created by 烟雀 on 2024/1/1.
//

import Foundation
import SwiftUI

struct SettingFormView: View{
    
    @State
    private var info = EventInfo.currentEventInfo()
    @State
    private var _doblueClickTime = Float64(EventInfo.currentEventInfo().dobulueClickTime)
    @State
    private var _alertTime = Float64(EventInfo.currentEventInfo().alterWinCloseTime)
    
    var body:  some View {
        
        VStack{
            Form{
                Section("间隔时间设置", content: {
                    
                    Slider(value: $_doblueClickTime, in: 1...8, label: {
                        Text("CMD+Q间隔时间: \(Int(self._doblueClickTime))")
                    })
                    Slider(value: $_alertTime, in: 1...8, label: {
                        Text("窗口关闭时间: \(Int(self._alertTime))")
                    })
                    
                })
                
                Button("保存", action: {
                    self.info.alterWinCloseTime = Int(self._alertTime)
                    self.info.dobulueClickTime = Int(self._doblueClickTime)
                })
            }
        }
        
    }
}



