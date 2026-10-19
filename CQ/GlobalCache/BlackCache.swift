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

    func load() -> [String] {
        normalize(fileStore.load([String].self) ?? [])
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

    private var recordSet: Set<String>
    private let store: WhitelistStore

    init(store: WhitelistStore = WhitelistStore()) {
        self.store = store
        self.records = []
        self.recordSet = []
        loadFromDisk()
    }

    private func loadFromDisk() {
        syncRecords(store.load())
    }

    /// 先持久化候选列表，成功后再同步列表及索引，保证写入失败不改变保护行为。
    private func persist(_ newRecords: [String]) -> Bool {
        guard store.save(newRecords) else { return false }
        syncRecords(newRecords)
        return true
    }

    func contains(_ path: String) -> Bool {
        recordSet.contains(path)
    }

    /// 添加白名单应用；重复项视为成功，写入失败时保留原有列表。
    @discardableResult
    func append(data: String?) -> Bool {
        guard let data, !data.isEmpty else { return false }
        guard !recordSet.contains(data) else { return true }
        return persist(records + [data])
    }

    /// 移除白名单应用；只有磁盘写入成功才更新命中索引。
    @discardableResult
    func remove(data: String?) -> Bool {
        guard let data, !data.isEmpty else { return false }
        guard recordSet.contains(data) else { return true }
        return persist(records.filter { $0 != data })
    }

    private func syncRecords(_ records: [String]) {
        self.records = records
        recordSet = Set(records)
    }
}
