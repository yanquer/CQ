//
//  AppBlack.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation
import Cocoa

struct AppPickerItem: Identifiable, Equatable {
    let name: String
    let path: String

    init(url: URL) {
        self.name = url.deletingPathExtension().lastPathComponent
        self.path = url.path
    }

    var id: String {
        path
    }
}

protocol InstalledAppCataloging {
    func loadApps(refresh: Bool) -> [AppPickerItem]
}

final class InstalledAppCatalog: InstalledAppCataloging {
    static let shared = InstalledAppCatalog()

    private let fileManager: FileManager
    private let appDirectories: [String]
    private var cachedItems: [AppPickerItem] = []

    init(
        fileManager: FileManager = .default,
        appDirectories: [String] = InstalledAppCatalog.defaultDirectories
    ) {
        self.fileManager = fileManager
        self.appDirectories = appDirectories
    }

    func loadApps(refresh: Bool = false) -> [AppPickerItem] {
        if !refresh, !cachedItems.isEmpty {
            return cachedItems
        }
        let items = scanInstalledApps()
        cachedItems = items
        return items
    }
}

private extension InstalledAppCatalog {
    static var defaultDirectories: [String] {
        [
            "/Applications",
            "\(NSHomeDirectory())/Applications",
            "/System/Applications"
        ]
    }

    func scanInstalledApps() -> [AppPickerItem] {
        var seen = Set<String>()
        let items = appDirectories.flatMap(loadApps(in:))
        return items
            .filter { seen.insert($0.path).inserted }
            .sorted(by: compareApps(_:_:))
    }

    func loadApps(in directory: String) -> [AppPickerItem] {
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        return enumerator.compactMap(makePickerItem(from:))
    }

    func makePickerItem(from element: Any) -> AppPickerItem? {
        guard let url = element as? URL else { return nil }
        guard url.pathExtension.lowercased() == "app" else { return nil }
        return AppPickerItem(url: url)
    }

    func compareApps(_ lhs: AppPickerItem, _ rhs: AppPickerItem) -> Bool {
        let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameOrder == .orderedSame {
            return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
        }
        return nameOrder == .orderedAscending
    }
}

final class AppBlack {
    static let this = AppBlack()

    private let workspace = NSWorkspace.shared
    private var currentAppPath: String?
    private var activateObserver: NSObjectProtocol?

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

    func isCurrentAppBlocked() -> Bool {
        if currentAppPath == nil {
            refreshCurrentAppPath()
        }

        guard let currentAppPath else {
            return false
        }

        return BlackList.this.contains(currentAppPath)
    }

    private func updateCurrentAppPath(_ notification: Notification) {
        let key = NSWorkspace.applicationUserInfoKey
        let app = notification.userInfo?[key] as? NSRunningApplication
        currentAppPath = app?.bundleURL?.path
    }
}
