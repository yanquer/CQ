//
//  AppFileStore.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation

final class AppFileStore {
    let fileURL: URL

    private let fileManager: FileManager

    init(
        fileName: String,
        folderName: String = "CQ",
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.fileURL = AppFileStore.makeFileURL(
            fileName: fileName,
            folderName: folderName,
            fileManager: fileManager
        )
    }

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    /// 区分首次缺失和真正读取失败，避免调用方把损坏数据当成空记录覆盖。
    func loadResult<T: Decodable>(_ type: T.Type) -> Result<T?, Error> {
        do {
            let data = try Data(contentsOf: fileURL)
            return .success(try JSONDecoder().decode(type, from: data))
        } catch {
            if isMissingFile(error) { return .success(nil) }
            AppLog.error("读取文件失败: \(error)")
            return .failure(error)
        }
    }

    /// 为允许降级为空的调用方保留简便读取接口。
    func load<T: Decodable>(_ type: T.Type) -> T? {
        try? loadResult(type).get()
    }

    /// 原子保存数据并返回是否成功，让上层在失败时保留原有内存状态。
    @discardableResult
    func save<T: Encodable>(_ value: T) -> Bool {
        do {
            try createDirectoryIfNeeded()
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            AppLog.error("写入文件失败: \(error)")
            return false
        }
    }

    private func createDirectoryIfNeeded() throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func isMissingFile(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain &&
            nsError.code == NSFileReadNoSuchFileError
    }

    private static func makeFileURL(
        fileName: String,
        folderName: String,
        fileManager: FileManager
    ) -> URL {
        let baseURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
        return baseURL
            .appendingPathComponent(folderName)
            .appendingPathComponent(fileName)
    }
}
