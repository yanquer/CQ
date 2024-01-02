//
//  MenuView.swift
//  CQ
//
//  Created by 烟雀 on 2024/1/2.
//

import Foundation
import SwiftUI

struct MenuView: View {
    
    @State private var keyMapWindow: NSWindow?
    
    @State
    private var _doblueClickTime = Float64(EventInfo.currentEventInfo().dobulueClickTime)
    @State
    private var _alertTime = Float64(EventInfo.currentEventInfo().alterWinCloseTime)
    
    var body: some View {
        
        VStack( alignment: .leading, spacing: 0) {
            Text("CQ")
                .font(Font.system(size: 15.0))
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 15.0)
                .padding(.top, 15.0)
                .padding(.bottom, 15.0)
            
            Divider()
                .padding(.horizontal, 10.0)
                .frame(width: 300)
        
            
            Group {
                HStack(
                    spacing: 0){
                        Image(systemName: "magicmouse")
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
                        Image(systemName: "keyboard")
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
                NSApplication.shared.terminate(self)
            }, label: {
                Text("Quit")
                    .foregroundColor(.black)
            })
            .background(content: {
                Color.green
            })
            .padding(.top, 15.0)
            .padding(.bottom, 10.0)
            .cornerRadius(100)
            .frame(width: 240, alignment: .trailing)
        }
        
    }
    
}


private extension MenuView {
    
    enum TextString {
        static let alertText: LocalizedStringKey = "Alert_Title"
        static let mouseText: LocalizedStringKey = "Mouse_Wheel_Title"
        static let keyMapText: LocalizedStringKey = "Key_Mapper_Title"
        static let alertDesc: LocalizedStringKey = "Alert_Desc"
        static let mouseDesc: LocalizedStringKey = "Mouse_Wheel_Desc"
        static let keyMapDesc: LocalizedStringKey = "Key_Mapper_Desc"
    }
}


#Preview {
    MenuView()
}


