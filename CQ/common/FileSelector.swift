//
//  FileSelector.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation
import Cocoa


class FileSelector{
    static func openFile(selectApp: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose a app"
        openPanel.prompt = "Choose"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = true
        // openPanel.allowedContentTypes = [.application, .applicationBundle]  // 允许选择的文件类型
        
        // 设置起始文件夹为 /Applications
        let applicationsURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        openPanel.directoryURL = applicationsURL
        
        openPanel.begin { (result) -> Void in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                guard let url = openPanel.url else { return }
                // 处理选择的文件URL（url）
                print("Selected file: \(url)")
                selectApp(url)
            }
        }
    }
}

