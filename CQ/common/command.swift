//
//  Command.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation
import SwiftUI

typealias JsonPasteData = [String: [String]]

class ShellCommand{
    static func exec(cmds: [String]) -> Process{
        return Process.launchedProcess(
            launchPath: "/bin/bash",
            arguments: cmds
        )
    }
}


extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex & 0xFF0000) >> 16) / 255.0
        let green = Double((hex & 0x00FF00) >> 8) / 255.0
        let blue = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}


class MaxArray{
    private var _maxLength: Int
    internal var _cache: [String]
    
    init(maxLength: Int = 50) {
        self._maxLength = maxLength
        self._cache = []
    }
    
    private func _maxCheck(){
        let num =  self._cache.count - self._maxLength
        if num > 0{
            self._cache.removeLast(num)
        }
    }
    
    func load(_ data: [String]?){
        if (data == nil) {return}
        self._cache = data!
        self._maxCheck()
    }
    
    func getAll() -> [String]{
        return self._cache
    }
    
    func append(_ data: String?){
        if (data == nil) {return}
        self._cache.append(data!)
        self._maxCheck()
    }
    
    func insert(_ data: String?, at: Int=0){
        if (data == nil) {return}
        self._cache.insert(data!, at: at)
        self._maxCheck()
    }
    
    func insertWithRm(_ data: String?, at: Int=0){
        if (data == nil) {return}
        if self.removeItem(data){
            self.insert(data, at: at)
        }
    }
    
    func removeItem(_ data: String?, at: Int=0) -> Bool{
        if (data == nil) {return true}
        if self._cache.contains(data!){
            if let strIndex = self._cache.firstIndex(of: data!){
                if (strIndex == at){return false}
                self._cache.remove(at: strIndex)
            }
        }
        return true
    }
    
}




