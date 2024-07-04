//
//  CButton.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation
import SwiftUI

struct CButton: View {
    
    var text: String
    var action: () -> Void = {}
    var fColor = Color.white
    var bgColor = Color.blue
    
    
    var body: some View {
        Button {
            action()
        } label: {
            Text(
                text
    //                                    ,systemImage: "digitalcrown.horizontal.press.fill"
            )
            .foregroundColor(fColor)
                .padding(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundColor(bgColor)
    //                                            .blur(radius: 2)
                    )
                .compositingGroup()
                .shadow(radius: 5,x:0,y:3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CButton(text: "Press")
}
