//
//  AppBlack.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation
import Cocoa

final class AppBlack {
    static let this = AppBlack()

    private let workspace = NSWorkspace.shared
    private var currentAppPath: String?
    private var activateObserver: NSObjectProtocol?
    private var cacheBlack: [String] = []

    private static func getAllInstalledApps() -> [URL] {
        let fileManager = FileManager.default
        var appURLs: [URL] = []
        let appDirectories = ["/Applications", "\(NSHomeDirectory())/Applications"]

        for directory in appDirectories {
            let url = URL(fileURLWithPath: directory)
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                do {
                    let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                    if values.isDirectory == true && fileURL.pathExtension == "app" {
                        appURLs.append(fileURL)
                    }
                } catch {
                    AppLog.info("读取应用目录失败: \(error.localizedDescription)")
                }
            }
        }

        return appURLs
    }

    func startObservingWorkspace() {
        if activateObserver != nil {
            refreshCurrentAppPath()
            return
        }

        refreshCurrentAppPath()
        activateObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.updateCurrentAppPath(notification)
        }
    }

    func stopObservingWorkspace() {
        guard let activateObserver else { return }
        workspace.notificationCenter.removeObserver(activateObserver)
        self.activateObserver = nil
    }

    func refreshCurrentAppPath() {
        currentAppPath = workspace.frontmostApplication?.bundleURL?.path
    }

    func getAllInstallApps(refresh: Bool = false) -> [String] {
        if refresh || cacheBlack.isEmpty {
            cacheBlack = AppBlack.getAllInstalledApps().map(\.path)
        }

        return cacheBlack
    }

    func isCurrentAppBlocked() -> Bool {
        if currentAppPath == nil {
            refreshCurrentAppPath()
        }

        guard let currentAppPath else {
            return false
        }

        return BlackList.this.records.contains(currentAppPath)
    }

    private func updateCurrentAppPath(_ notification: Notification) {
        let key = NSWorkspace.applicationUserInfoKey
        let app = notification.userInfo?[key] as? NSRunningApplication
        currentAppPath = app?.bundleURL?.path
    }
}
