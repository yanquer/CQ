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

    /// 从已知展示数据构造应用条目，供预览使用固定应用样例。
    init(name: String, path: String) {
        self.name = name
        self.path = path
    }

    /// 读取应用的本地化显示名称，并保留路径作为稳定身份与搜索依据。
    init(url: URL) {
        self.name = Self.displayName(for: url)
        self.path = url.path
    }

    var id: String {
        path
    }

    /// 优先使用本地化包名称，缺失时回退到 Finder 名称及应用文件名。
    private static func displayName(for url: URL) -> String {
        let bundle = Bundle(url: url)
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            if let name = bundle?.object(forInfoDictionaryKey: key) as? String,
               !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return name
            }
        }
        let filename = FileManager.default.displayName(atPath: url.path)
        return filename.lowercased().hasSuffix(".app") ? String(filename.dropLast(4)) : filename
    }
}

/// 保留扫描目录及原始错误，供界面区分失败与有效空结果。
struct AppCatalogFailure {
    let directory: String
    let error: NSError
}

/// 同时返回可用应用与扫描失败，支持部分目录可读的情况。
struct AppCatalogResult {
    let items: [AppPickerItem]
    var failures: [AppCatalogFailure] = []
}

protocol InstalledAppCataloging {
    func loadApps(refresh: Bool) -> AppCatalogResult
}

final class InstalledAppCatalog: InstalledAppCataloging {
    static let shared = InstalledAppCatalog()

    private let fileManager: FileManager
    private let appDirectories: [String]
    private var cachedResult: AppCatalogResult?
    private let scanLock = NSLock()

    init(
        fileManager: FileManager = .default,
        appDirectories: [String] = InstalledAppCatalog.defaultDirectories
    ) {
        self.fileManager = fileManager
        self.appDirectories = appDirectories
    }

    /// 串行保护共享目录缓存，避免多个面板在不同后台队列上同时读写。
    func loadApps(refresh: Bool = false) -> AppCatalogResult {
        scanLock.lock()
        defer { scanLock.unlock() }
        if !refresh, let cachedResult {
            return cachedResult
        }
        let startedAt = ProcessInfo.processInfo.systemUptime
        AppLog.debug("App catalog scan started: roots=\(appDirectories.count)")
        let result = scanInstalledApps()
        cachedResult = result
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        AppLog.info("App catalog scan completed: apps=\(result.items.count), failedRoots=\(result.failures.count), elapsed=\(elapsed)")
        return result
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

    /// 合并各目录的有效应用和失败信息，并按路径去重、名称排序。
    func scanInstalledApps() -> AppCatalogResult {
        var seen = Set<String>()
        let results = appDirectories.map(loadApps(in:))
        let items = results.flatMap(\.items)
            .filter { seen.insert($0.path).inserted }
            .sorted(by: compareApps(_:_:))
        return AppCatalogResult(items: items, failures: results.flatMap(\.failures))
    }

    /// 不存在的可选应用目录视为空目录，读取失败保留首个原始错误及已读出的应用。
    func loadApps(in directory: String) -> AppCatalogResult {
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else {
                throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: "应用扫描路径不是目录"])
            }
        } catch {
            let error = error as NSError
            if error.domain == NSCocoaErrorDomain,
               [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) {
                return AppCatalogResult(items: [])
            }
            return AppCatalogResult(items: [], failures: [recordFailure(directory: directory, error: error)])
        }
        var failure: AppCatalogFailure?
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { failedURL, error in
                // 每个根目录只保留并记录首个错误，避免不可读子目录造成无界日志和内存占用。
                if failure == nil {
                    failure = self.recordFailure(directory: failedURL.path, error: error as NSError)
                }
                return true
            }
        ) else {
            let error = CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: "无法创建应用目录枚举器"])
            return AppCatalogResult(items: [], failures: [recordFailure(directory: directory, error: error as NSError)])
        }
        let items = enumerator.compactMap(makePickerItem(from:))
        return AppCatalogResult(items: items, failures: failure.map { [$0] } ?? [])
    }

    /// 将首个失败原因写入统一日志，保留目录、错误域、原始错误码及有界消息。
    func recordFailure(directory: String, error: NSError) -> AppCatalogFailure {
        let message = String(error.localizedDescription.prefix(512)).replacingOccurrences(of: "\n", with: " ")
        let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError
        AppLog.error("App catalog scan failed: directory=\(directory), domain=\(error.domain), code=\(error.code), underlyingDomain=\(underlying?.domain ?? "none"), underlyingCode=\(underlying?.code ?? 0), message=\(message)")
        return AppCatalogFailure(directory: directory, error: error)
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

    /// 释放时清理通知订阅，避免遗留监听。
    deinit {
        if let activateObserver { workspace.notificationCenter.removeObserver(activateObserver) }
    }
}
