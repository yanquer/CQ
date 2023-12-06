//
//  Command.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//

import Foundation

class ShellCommand{
    static func exec(cmds: [String]) -> Process{
        return Process.launchedProcess(
            launchPath: "/bin/bash",
            arguments: cmds
        )
    }
}


