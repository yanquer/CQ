//
//  AppFileStore.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation

final class AppFileStore {
    static let maximumFileSize = 1_048_576

    /// 文件大小超过安全读取上限时拒绝处理，防止异常文件消耗无界内存。
    private enum StoreError: Error {
        case fileTooLarge
    }

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

    /// 分块读取并限制总量，首次缺失与损坏或超限保持不同结果。
    func loadDataResult() -> Result<Data?, Error> {
        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }
            var data = Data()
            while let chunk = try handle.read(upToCount: min(65_536, Self.maximumFileSize + 1 - data.count)), !chunk.isEmpty {
                data.append(chunk)
                guard data.count <= Self.maximumFileSize else { throw StoreError.fileTooLarge }
            }
            return .success(data)
        } catch {
            if isMissingFile(error) { return .success(nil) }
            AppLog.error("读取文件失败: \(fileURL.lastPathComponent), error=\(error)")
            return .failure(error)
        }
    }

    /// 在有界读取成功后解码，避免把损坏文件当成空记录。
    func loadResult<T: Decodable>(_ type: T.Type) -> Result<T?, Error> {
        loadDataResult().flatMap { data in
            guard let data else { return .success(nil) }
            do {
                return .success(try JSONDecoder().decode(type, from: data))
            } catch {
                AppLog.error("解码文件失败: \(fileURL.lastPathComponent), error=\(error)")
                return .failure(error)
            }
        }
    }

    /// 为允许降级为空的调用方保留简便读取接口。
    func load<T: Decodable>(_ type: T.Type) -> T? {
        try? loadResult(type).get()
    }

    /// 原子保存有界数据，失败时保留原文件。
    @discardableResult
    func saveData(_ data: Data) -> Bool {
        do {
            guard data.count <= Self.maximumFileSize else { throw StoreError.fileTooLarge }
            try createDirectoryIfNeeded()
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            AppLog.error("写入文件失败: \(fileURL.lastPathComponent), error=\(error)")
            return false
        }
    }

    /// 编码并通过统一的大小限制和原子写入保存数据。
    @discardableResult
    func save<T: Encodable>(_ value: T) -> Bool {
        do {
            return saveData(try JSONEncoder().encode(value))
        } catch {
            AppLog.error("编码文件失败: \(error)")
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
        return (nsError.domain == NSCocoaErrorDomain &&
            [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(nsError.code)) ||
            (nsError.domain == NSPOSIXErrorDomain && nsError.code == ENOENT)
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
