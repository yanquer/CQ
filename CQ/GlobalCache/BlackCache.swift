//
//  BlackCache.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Combine
import Foundation

final class WhitelistStore {
    private let fileStore: AppFileStore

    init(fileStore: AppFileStore = AppFileStore(fileName: "whitelist.json")) {
        self.fileStore = fileStore
    }

    init(fileURL: URL) {
        self.fileStore = AppFileStore(fileURL: fileURL)
    }

    var fileURL: URL {
        fileStore.fileURL
    }

    /// 保留读取失败信息，只有首次缺失才视为空白名单。
    func loadResult() -> Result<[String]?, Error> {
        fileStore.loadResult([String].self).map { $0.map(normalize) }
    }

    func load() -> [String] {
        (try? loadResult().get()) ?? []
    }

    /// 返回规范化后的白名单是否成功写入磁盘。
    @discardableResult
    func save(_ records: [String]) -> Bool {
        fileStore.save(normalize(records))
    }

    private func normalize(_ records: [String]) -> [String] {
        var seen = Set<String>()
        return records.filter {
            guard !$0.isEmpty, !seen.contains($0) else { return false }
            seen.insert($0)
            return true
        }
    }
}

final class BlackList: ObservableObject {
    static let this = BlackList()

    @Published private(set) var records: [String]
    @Published private(set) var storageError: String?
    private var requiresReload = false

    private var recordSet: Set<String>
    private let store: WhitelistStore

    init(store: WhitelistStore = WhitelistStore()) {
        self.store = store
        self.records = []
        self.recordSet = []
        loadFromDisk()
    }

    /// 读取失败时保留内存和原文件，向界面报告错误；恢复后可在下一次操作前重读。
    private func loadFromDisk() {
        switch store.loadResult() {
        case .success(let loadedRecords):
            syncRecords(loadedRecords ?? records)
            requiresReload = false
            storageError = nil
        case .failure:
            requiresReload = true
            storageError = "白名单无法读取，已保留原文件。修复文件或访问权限后重试。"
        }
    }

    /// 修改前检查磁盘仍可读取，避免启动后发生的文件损坏被静默覆盖。
    private func prepareMutation() -> Bool {
        if requiresReload { loadFromDisk() }
        guard !requiresReload else { return false }
        if case .failure = store.loadResult() {
            requiresReload = true
            storageError = "白名单无法读取，已保留原文件。修复文件或访问权限后重试。"
            return false
        }
        return true
    }

    /// 先持久化候选列表，成功后再同步列表及索引，保证写入失败不改变保护行为。
    private func persist(_ newRecords: [String]) -> Bool {
        guard store.save(newRecords) else {
            storageError = "未能保存白名单，原列表保持不变。请稍后重试。"
            return false
        }
        syncRecords(newRecords)
        storageError = nil
        return true
    }

    /// 先按实际路径常数时间命中，必要时解析路径别名；不在每次按键时遍历白名单。
    func contains(_ path: String) -> Bool {
        recordSet.contains(path) || recordSet.contains(canonicalPath(path))
    }

    /// 统一同一应用的符号链接路径；相对路径不解释为当前工作目录下的应用。
    private func canonicalPath(_ path: String) -> String {
        guard path.hasPrefix("/") else { return path }
        return URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// 添加白名单应用；重复项视为成功，写入失败时保留原有列表。
    @discardableResult
    func append(data: String?) -> Bool {
        guard let data, !data.isEmpty, prepareMutation() else { return false }
        guard !contains(data) else { storageError = nil; return true }
        return persist(records + [data])
    }

    /// 移除白名单应用；只有磁盘写入成功才更新命中索引。
    @discardableResult
    func remove(data: String?) -> Bool {
        guard let data, !data.isEmpty, prepareMutation() else { return false }
        guard contains(data) else { storageError = nil; return true }
        let canonical = canonicalPath(data)
        return persist(records.filter { canonicalPath($0) != canonical })
    }

    /// 按规范路径去重并更新索引，显示和保存仍保留用户选择的原始路径。
    private func syncRecords(_ records: [String]) {
        var paths = Set<String>()
        let normalized = records.filter { paths.insert(canonicalPath($0)).inserted }
        recordSet = paths
        self.records = normalized
    }
}
