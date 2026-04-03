//
//  FileSelector.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Cocoa
import Foundation
import UniformTypeIdentifiers

protocol SystemAppPicking {
    func pickApp() -> URL?
}

struct SystemAppPicker: SystemAppPicking {
    func pickApp() -> URL? {
        let openPanel = NSOpenPanel()
        configure(openPanel)
        NSApp.activate(ignoringOtherApps: true)
        guard openPanel.runModal() == .OK else { return nil }
        guard let url = openPanel.url else { return nil }
        AppLog.info("Selected app: \(url.path)")
        return url
    }
}

private extension SystemAppPicker {
    func configure(_ openPanel: NSOpenPanel) {
        openPanel.title = "选择应用"
        openPanel.prompt = "添加"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.treatsFilePackagesAsDirectories = false
        openPanel.allowedContentTypes = [.applicationBundle]
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    }
}
