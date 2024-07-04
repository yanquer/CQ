//
//  SettingView.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation
import SwiftUI

struct SettingView: View{
    
    @State private var showGenerate = true
    @State private var showBlack = false

    private let mainBgColor = Color(red: 0.32, green: 0.32, blue: 0.38)
    
    var body: some View {
        VStack {
            
            Text("CQ")
                .font(Font.system(size: 15.0))
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 15.0)
                .padding(.top, 15.0)
//                .padding(.bottom, 15.0)
            
//            Divider()
//                .padding(.horizontal, 10.0)
//                .frame(width: 300)
            
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(mainBgColor.opacity(0.5))
                    .blur(radius: /*@START_MENU_TOKEN@*/3.0/*@END_MENU_TOKEN@*/)
                    .frame(width: 300, height: 30)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                
                HStack {
                    CButton(text: "通用", action: {
                        showGenerate = true
                        showBlack = false
                    }, fColor: showGenerate ? Color.blue : Color.white, bgColor: Color.clear)
                    
                    CButton(text: "白名单", action: {
                        showGenerate = false
                        showBlack = true
                    }, fColor: showBlack ? Color.blue : Color.white, bgColor: Color.clear)
                    
//                    .frame(width: 120, alignment: .leading)
                    
                }.frame(height: 40)
            }
            
            Divider()
                .padding(.horizontal, 10.0)
                .frame(width: 300)
            
            if showGenerate {
                MenuView()
            } else if showBlack {
                BlackView()
            }
            
        }
        .padding(/*@START_MENU_TOKEN@*/.all, 0.0/*@END_MENU_TOKEN@*/)
        .frame(width: 300, height: 360)
    }
    
}


#Preview {
    SettingView()
}

