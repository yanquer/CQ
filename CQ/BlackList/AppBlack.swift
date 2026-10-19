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

/// 监听前台切换以清理退出确认；白名单判断由按键时的应用快照完成。
final class AppBlack {
    static let this = AppBlack()
    private let workspace = NSWorkspace.shared
    private var activateObserver: NSObjectProtocol?

    /// 监听前台应用切换，通知退出保护清除旧确认状态。
    func startObservingWorkspace(onActivation: @escaping () -> Void = {}) {
        guard activateObserver == nil else { return }
        activateObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { _ in onActivation() }
    }

    /// 移除前台切换监听，避免停止后继续响应通知。
    func stopObservingWorkspace() {
        guard let activateObserver else { return }
        workspace.notificationCenter.removeObserver(activateObserver)
        self.activateObserver = nil
    }

    deinit {
        if let activateObserver { workspace.notificationCenter.removeObserver(activateObserver) }
    }
}
