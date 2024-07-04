//
//  BlackCache.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation


class BlackList: ObservableObject{
    // 单例
    static let this = BlackList()
    let cacheToDisk = CacheDisk()
    
    @Published
    var records: [String] = []
    
    init() {
        self.loadFromDisk()
    }
    
    private var allData: JsonPasteData? = [:]
    
    private func loadFromDisk(){
        if let jsonData = self.cacheToDisk.loadFromCache(){
            allData = jsonData
            if let diskRecords = jsonData["diskData"]{
                self.records = diskRecords
            }
        }
    }
    
    private func cache(){
        allData!["diskData"] = self.records
        self.cacheToDisk.writeToCache(data: allData!)
    }
    
    func append(data: String?){
        if (data == nil || data == "" || data!.isEmpty) {return}
        self.records.append(data!)
        self.cache()
    }
    
    func remove(data: String?){
        if (data == nil || data == "" || data!.isEmpty) {return}
        
        guard let findIndex = self.records.firstIndex(of: data!) else {return}
        self.records.remove(at: findIndex)
        self.cache()
    }

}


class BlackCache{
    let this = BlackCache()
    
    
    
}

