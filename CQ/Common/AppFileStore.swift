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

    func load<T: Decodable>(_ type: T.Type) -> T? {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            handleLoadError(error)
            return nil
        }
    }

    func save<T: Encodable>(_ value: T) {
        do {
            try createDirectoryIfNeeded()
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            AppLog.error("写入文件失败: \(error)")
        }
    }

    private func createDirectoryIfNeeded() throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func handleLoadError(_ error: Error) {
        // 首次启动时文件不存在属于正常情况，这里直接按空状态处理。
        guard !isMissingFile(error) else { return }
        AppLog.error("读取文件失败: \(error)")
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
