//
//  AppBlack.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation
import Cocoa


class AppBlack{
    
    static let this = AppBlack()
    
    static private func currentFoucApp() -> String?{
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appName = frontApp.localizedName ?? "Unknown"
            print("当前前台应用程序是：\(appName)")
            return appName
        }
        return nil
    }
    
    static private func getAllInstalledApps() -> [URL] {
        let fileManager = FileManager.default
        var appURLs: [URL] = []
        
        // 可能的应用程序目录
        // 仅扫描当前用户安装的APP
        let appDirectories = [
            "/Applications",
            // "/System/Applications",
            // "/System/Library/CoreServices",
             "\(NSHomeDirectory())/Applications"
        ]
        
        for directory in appDirectories {
            let url = URL(fileURLWithPath: directory)
            if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                        if let isDirectory = resourceValues.isDirectory, isDirectory, fileURL.pathExtension == "app" {
                            appURLs.append(fileURL)
                        }
                    } catch {
                        print("Error retrieving resource values for \(fileURL): \(error)")
                    }
                }
            }
        }
        
        return appURLs
    }
    
    private var cacheBlack: [String] = []
    func getAllInstallApps(refresh: Bool=false) -> [String]{
        
        if (refresh || self.cacheBlack.isEmpty){
            let installedApps = AppBlack.getAllInstalledApps()
            installedApps.forEach {
                print($0.path)
                self.cacheBlack.append($0.path)
            }
        }
        
        return self.cacheBlack
        
    }
    
//    private var cacheAppBlack: [AppItem] = []
//    func getAllInstallAppModel(refresh: Bool=false) -> [AppItem]{
//        
//        if (refresh || self.cacheAppBlack.isEmpty){
//            self.getAllInstallApps(refresh: true).forEach {
//                self.cacheAppBlack.append(AppItem(name: $0, appPath: $0))
//            }
//        }
//        
//        return self.cacheAppBlack
//        
//    }
//    
    
    
    
    
}


