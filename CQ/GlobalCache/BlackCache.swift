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

    func save(_ records: [String]) {
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

    private func persist() {
        store.save(records)
    }

    func contains(_ path: String) -> Bool {
        recordSet.contains(path)
    }

    func append(data: String?) {
        guard let data, !data.isEmpty else { return }
        guard recordSet.insert(data).inserted else { return }
        records.append(data)
        persist()
    }

    func remove(data: String?) {
        guard let data, !data.isEmpty else { return }
        guard recordSet.remove(data) != nil else { return }
        records.removeAll { $0 == data }
        persist()
    }

    private func syncRecords(_ records: [String]) {
        self.records = records
        recordSet = Set(records)
    }
}
