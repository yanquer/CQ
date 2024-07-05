//
//  MenuView.swift
//  CQ
//
//  Created by 烟雀 on 2024/1/2.
//

import Foundation
import SwiftUI

struct MenuView: View {
    
    private let info = EventInfo.currentEventInfo()
    
    @State private var keyMapWindow: NSWindow?
    
    @State
    private var _doblueClickTime = Float64(EventInfo.currentEventInfo().dobulueClickTime)
    @State
    private var _alertTime = Float64(EventInfo.currentEventInfo().alterWinCloseTime)
    
    @State
    private var _startAtLogin = AutoLaunch.isEnabledAutoLaunch
    
    var body: some View {
        
        VStack( alignment: .leading, spacing: 0) {
            
        
            Toggle(isOn: $_startAtLogin){
                Text("登陆时启动")
                    .fontWeight(.medium)
                    .padding(.top, 5.0)
                    .frame(width: 200, alignment: .leading)
            }
                .padding()
                .onChange(of: _startAtLogin, initial: false) { (oldValue, newValue) in
                    if newValue {
                        AutoLaunch.enableAutoLaunch()
                    } else {
                        AutoLaunch.disableAutoLaunch()
                    }
                    // _startAtLogin = newValue
                }
            
            Divider()
                .padding(.horizontal, 10.0)
                .frame(width: 300)
            
            Group {
                HStack(
                    spacing: 0){
                        Image(systemName: "gear")
                            .padding(.top, 15.0)
                            .padding(.leading, 15.0)
                            .frame(width: 40, alignment: .leading)
                        
                        Text("CMD+Q最长间隔时间")
                            .fontWeight(.medium)
                            .padding(.top, 15.0)
                            .frame(width: 200, alignment: .leading)
                    }
                Slider(value: $_doblueClickTime, in: 1...8, label: {
                    Text("\(Int(self._doblueClickTime))")
                        .font(Font.system(size: 12.0))
                        .fontWeight(.light)
                        .colorMultiply(.brown)
                }).frame(width: 200, alignment: .leading)
                    .padding(.leading, 15.0)
                    .padding(.top, 15.0)
                    .padding(.bottom, 15.0)
            }
            
            Divider()
                .padding(.horizontal, 10.0)
                .frame(width: 300)
            
            Group {
                HStack(
                    spacing: 0) {
                        Image(systemName: "gear")
                            .padding(.top, 15.0)
                            .padding(.leading, 15.0)
                            .frame(width: 40, alignment: .leading)
                        
                        Text("提示窗口关闭时间")
                            .fontWeight(.medium)
                            .padding(.top, 15.0)
                            .frame(width: 200, alignment: .leading)
                    }
                Slider(value: $_alertTime, in: 1...8, label: {
                    Text("\(Int(self._alertTime))")
                        .font(Font.system(size: 12.0))
                        .fontWeight(.light)
                        .colorMultiply(.brown)
                }).frame(width: 200, alignment: .leading)
                    .padding(.leading, 15.0)
                    .padding(.top, 15.0)
                    .padding(.bottom, 15.0)
            }
            Divider()
                .padding(.horizontal, 10.0)
                .frame(width: 300)
        }
        
        
        HStack {
            Button(action: {
                updateClickTime()
                updateAlertCloseTime()
            }, label: {
                Text("应用")
                    // .foregroundColor(.yellow)
            })
            .padding(.top, 15.0)
            .padding(.bottom, 10.0)
            .cornerRadius(100)
            .frame(width: 120, alignment: .leading)
            
            Button(action: {
                NSApplication.shared.terminate(self)
            }, label: {
                Text("退出")
                    // .foregroundColor(.yellow)
            })
            .padding(.top, 15.0)
            .padding(.bottom, 10.0)
            .cornerRadius(100)
            .frame(width: 120, alignment: .trailing)
        }
        
    }
    
}


extension MenuView{
    
    func updateClickTime(){
        info.dobulueClickTime = Int(self._doblueClickTime)
    }
    
    func updateAlertCloseTime(){
        info.alterWinCloseTime = Int(self._alertTime)
    }
}


#Preview {
    MenuView()
}


