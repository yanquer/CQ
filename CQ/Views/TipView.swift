//
//  TipView.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/9.
//

import Foundation
import SwiftUI

public struct BlurView: NSViewRepresentable {
    public typealias NSViewType = NSVisualEffectView
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .withinWindow
        effectView.state = NSVisualEffectView.State.active
        return effectView
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .hudWindow
        nsView.blendingMode = .withinWindow
    }
}

struct TipView: View {
    
    let alertText: String
    let sizeX: CGFloat = TipViewSize.width
    let sizeY: CGFloat = TipViewSize.height
    
    var body: some View {
        ZStack {
            // BlurView()
            // Color.black.opacity(0.5).blur(radius: 10)
            Text(alertText)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.3).blur(radius: 10))
                .cornerRadius(10)
        }
        .font(Font.system(size: 20.0))
        // .background(Color.brown.opacity(0.3).blur(radius: 10))
        .background(Color.clear)
        .frame(width: self.sizeX, height: self.sizeY)
        .padding(.top, 40.0)
        .edgesIgnoringSafeArea(.all)
        
    }
    
}



#Preview {
    TipView(alertText: "test")
}


