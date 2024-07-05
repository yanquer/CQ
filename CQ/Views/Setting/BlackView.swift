//
//  BlackView.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation
import SwiftUI


struct BlackView: View {
    
    // @State private var whitelistItems: [String] = BlackList.this.records // 白名单数据项
    @ObservedObject private var whitelistObj: BlackList = BlackList.this
    
    
    @State private var selectedItem: String? = nil
    
    private let mainBgColor = Color(red: 0.32, green: 0.32, blue: 0.38)

    var body: some View {
        VStack {
            Text("跳过以下程序的 `Cmd+Q` 检查")
                .padding(.top, 10)
                
            ScrollView{
                
                    
                VStack(spacing: 0){
//                        List(whitelistItems.indices, id: \.self) { index in
//                            Text(whitelistItems[index])
//                                .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, alignment: .leading)
//                                .contentShape(
//                                    Rectangle()
//                                ) // 使整个行可点击
//                                .onTapGesture {
//                                    selectedIndex = index
//                                }
//                                .listRowBackground(selectedIndex == index ? Color.gray.opacity(0.3) : mainBgColor) // 高亮选择的项
//                        }
//                        .frame(height: .infinity)
//                        .scrollContentBackground(.hidden)
//                        // 渐变背景色
//                        // .background(.linearGradient(colors: [.white, .accentColor], startPoint: .top, endPoint: .bottom))
//                        .background(mainBgColor)
                    
                    LazyVStack(spacing: 0) {
                        ForEach(whitelistObj.records, id: \.self) { item in
                                        Button(action: {
                                            selectedItem = item
                                        }, label: {
                                            Text(item)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .frame(height: 0)
                                                .padding()
                                                .background(selectedItem == item ? Color.blue.opacity(0.1) : mainBgColor)
                                                // .cornerRadius(8)     // 圆角
                                        })
                                        .buttonStyle(.plain)
                                        
                                    }
                                }
                    .padding(.all, 0)
                    
                    
                    
                    Divider()
                        .padding(.horizontal, 10.0)
                        .frame(width: 300)
        
                    HStack(spacing: 0) {
                        CButton(text: "+", action: {
                            FileSelector.openFile(selectApp: {appPath in
                                AppLog.info("select \(appPath!)")
                                whitelistObj.append(data: appPath!.path)
                            })
                        }, bgColor: Color.clear)
                        
                        Text("|")
                            .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.75))
                        
                        CButton(text: "-", action: {
                            whitelistObj.remove(data: selectedItem)
                        }, bgColor: Color.clear)
                        .disabled(selectedItem == nil)
                        
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 5)
                        
                    
                }
                
            }
//            .frame(width: 295, height: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 8) // 设置圆角矩形
                        .stroke(Color.gray, lineWidth: 1) // 设置边框颜色和宽度
                )
            
            
            
            
        }
            .frame(width: 300)
            .background(mainBgColor)

        

        
    }
}




#Preview {
    BlackView()
}



