//
//  CacheDisk.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation
import SwiftUI

class CacheDisk{
    static private var appDir: String = Bundle.main.bundlePath
    static private var cacheDir: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(string: appDir)!
    
    static private var cacheFile: URL = cacheDir.appendingPathComponent("cacheCQ.json")
    
    init(){
        AppLog.debug("cache file: " + CacheDisk.cacheFile.path())
    }
    
    func writeToCache(data: JsonPasteData){
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            // let jsonStr = String(data: jsonData, encoding: .utf8)
            
            try jsonData.write(to: CacheDisk.cacheFile)
            AppLog.debug("writeToCache success")
        } catch {
            AppLog.error("writeToCache error: \(error)")
        }
    }
    
    func loadFromCache() -> JsonPasteData? {
        do {
            let jsonData = try Data(contentsOf: CacheDisk.cacheFile)
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? JsonPasteData {
                AppLog.debug("loadFromCache success")
                return jsonObject
            }
        }catch{
            AppLog.error("loadFromCache error: \(error)")
        }
        return nil
    }
}


