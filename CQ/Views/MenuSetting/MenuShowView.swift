//
//  MenuShowView.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/5.
//

import Foundation
import SwiftUI


struct MenuShowView: View{
    
    // var settingView: NSWindow?
    
    var body: some View{
        
        VStack(spacing: 0){
            
            Divider()
                .padding(.horizontal, 10.0)
                .frame(width: 300)
            
            HStack{
                CButton(text: "更多设置...", action: {
                    _ = SettingView().showViewOnNewWindow(title: "CQ")
                },
                        fColor: Color.black,
                        bgColor: Color.cyan
                )
                .frame(alignment: .leading)
                .padding(.leading, 15)
            }
                .frame(maxWidth: 300, alignment: .leading)
                .padding(.vertical, 10)
        
            
            Divider()
                .padding(.horizontal, 10.0)
                .frame(width: 300)
            
            MenuView()
            
            
        }
    }
}

#Preview{
    MenuShowView()
}
