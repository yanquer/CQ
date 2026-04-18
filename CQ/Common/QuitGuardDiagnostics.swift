//
//  QuitGuardDiagnostics.swift
//  CQ
//
//  负责沉淀退出保护的权限快照、tap 快照、环境诊断与遥测落盘，
//  用来解决 mac mini 上进程仍在但 Cmd+Q 拦截失效时缺少证据链的问题。
//

import ApplicationServices
import Foundation
import Security

enum CodeSignatureStatus: String, Codable, Equatable {
    case valid
    case invalid
    case unavailable
}

enum DeclaredSandboxState: String, Codable, Equatable {
    case enabled
    case disabled
    case unknown
}

enum SuspectedFailureReason: String, Codable, Equatable {
    case none
    case missingAccessibility
    case missingListenEvent
    case tapCreateReturnedNil
    case tapDisabledBySystem
    case invalidCodeSignature
    case declaredSandboxButUnavailable
    case unknown
}

enum TapFailureReason: String, Codable, Equatable {
    case tapCreateReturnedNil
    case tapDisabledBySystem
}

enum EventTapLocationName: String, Codable, Equatable {
    case session = "cgSessionEventTap"
    case hid = "cghidEventTap"
}

enum EventTapOptionName: String, Codable, Equatable {
    case defaultTap
}

enum QuitGuardTelemetryEvent: String, Codable, Equatable {
    case launchSync = "launch_sync"
    case wakeSync = "wake_sync"
    case permissionRefresh = "permission_refresh"
    case tapCreateAttempt = "tap_create_attempt"
    case tapCreateResult = "tap_create_result"
    case tapDisabled = "tap_disabled"
    case tapRecoveryResult = "tap_recovery_result"
    case environmentDiagnosed = "environment_diagnosed"
}

struct PermissionSnapshot: Codable, Equatable {
    let isAccessibilityTrusted: Bool
    let hasListenEventAccess: Bool
}

struct EventTapAttemptSnapshot: Codable, Equatable {
    let location: EventTapLocationName
    let option: EventTapOptionName
    let succeeded: Bool
}

struct TapSnapshot: Codable, Equatable {
    let currentLocation: EventTapLocationName?
    let currentOption: EventTapOptionName?
    let isEnabled: Bool
    let lastFailureReason: TapFailureReason?
    let attempts: [EventTapAttemptSnapshot]

    static let idle = TapSnapshot(
        currentLocation: nil,
        currentOption: nil,
        isEnabled: false,
        lastFailureReason: nil,
        attempts: []
    )
}

struct EnvironmentSnapshot: Codable, Equatable {
    let pid: Int32
    let bundlePath: String
    let bundleIdentifier: String
    let codeSignatureStatus: CodeSignatureStatus
    let declaredSandboxState: DeclaredSandboxState
    let hasInvalidEntitlements: Bool
    let hasKnownUnsupportedEnvironment: Bool
}

struct QuitGuardDiagnosticSnapshot: Codable, Equatable {
    let pid: Int32
    let bundlePath: String
    let bundleIdentifier: String
    let permissionSnapshot: PermissionSnapshot
    let tapSnapshot: TapSnapshot
    let codeSignatureStatus: CodeSignatureStatus
    let declaredSandboxState: DeclaredSandboxState
    let hasInvalidEntitlements: Bool
    let hasKnownUnsupportedEnvironment: Bool
    let suspectedFailureReason: SuspectedFailureReason
    let timestamp: Date

    /// 返回当前诊断结果是否允许继续启动全局拦截。
    var canActivateTap: Bool {
        suspectedFailureReason == .none
    }
}

struct QuitGuardTelemetryEntry: Codable, Equatable {
    let event: QuitGuardTelemetryEvent
    let snapshot: QuitGuardDiagnosticSnapshot
}

struct QuitGuardDiagnosticReport: Codable, Equatable {
    let latestEvent: QuitGuardTelemetryEvent
    let latestSnapshot: QuitGuardDiagnosticSnapshot
    let entries: [QuitGuardTelemetryEntry]
}

struct QuitGuardBundleInfo: Equatable {
    let bundlePath: String
    let bundleIdentifier: String
}

struct EventTapStrategy: Equatable {
    let location: CGEventTapLocation
    let placement: CGEventTapPlacement
    let options: CGEventTapOptions
    let locationName: EventTapLocationName
    let optionName: EventTapOptionName

    static let defaultStrategies: [EventTapStrategy] = [
        .sessionDefault,
        .hidDefault
    ]

    private static let sessionDefault = EventTapStrategy(
        location: .cgSessionEventTap,
        placement: .headInsertEventTap,
        options: .defaultTap,
        locationName: .session,
        optionName: .defaultTap
    )

    private static let hidDefault = EventTapStrategy(
        location: .cghidEventTap,
        placement: .headInsertEventTap,
        options: .defaultTap,
        locationName: .hid,
        optionName: .defaultTap
    )
}

protocol QuitGuardDiagnosing {
    /// 基于权限、tap 与环境信息生成完整的退出保护诊断快照。
    /// - Parameters:
    ///   - availability: 当前权限快照。
    ///   - tapSnapshot: 当前 tap 运行快照。
    /// - Returns: 可用于判断和落盘的诊断结果。
    func makeSnapshot(
        availability: QuitGuardAvailability,
        tapSnapshot: TapSnapshot
    ) -> QuitGuardDiagnosticSnapshot
}

protocol QuitGuardTelemetryWriting {
    /// 记录一次退出保护遥测事件，并同步写入统一日志和本地诊断文件。
    /// - Parameters:
    ///   - event: 当前要记录的事件名。
    ///   - snapshot: 与事件对应的诊断快照。
    func record(event: QuitGuardTelemetryEvent, snapshot: QuitGuardDiagnosticSnapshot)
}

protocol QuitGuardDiagnosticPersisting {
    /// 读取已经存在的退出保护诊断报告。
    /// - Returns: 当前磁盘中的诊断报告。
    func loadReport() -> QuitGuardDiagnosticReport?

    /// 保存最新的退出保护诊断报告。
    /// - Parameter report: 待写入磁盘的诊断报告。
    /// - Returns: 是否写入成功。
    func saveReport(_ report: QuitGuardDiagnosticReport) -> Bool
}

final class QuitGuardDiagnosticStore: QuitGuardDiagnosticPersisting {
    private let fileURL: URL
    private let fileManager: FileManager

    init(
        fileName: String = "quit-guard-diagnostics.json",
        folderName: String = "CQ",
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.fileURL = AppFileStore(
            fileName: fileName,
            folderName: folderName,
            fileManager: fileManager
        ).fileURL
    }

    /// 读取已经存在的退出保护诊断报告。
    /// - Returns: 当前磁盘中的诊断报告。
    func loadReport() -> QuitGuardDiagnosticReport? {
        do {
            let data = try Data(contentsOf: fileURL)
            return try makeDecoder().decode(QuitGuardDiagnosticReport.self, from: data)
        } catch {
            guard !isMissingFile(error) else { return nil }
            AppLog.error("读取退出保护诊断文件失败: \(error)")
            return nil
        }
    }

    /// 保存最新的退出保护诊断报告。
    /// - Parameter report: 待写入磁盘的诊断报告。
    /// - Returns: 是否写入成功。
    func saveReport(_ report: QuitGuardDiagnosticReport) -> Bool {
        do {
            try createDirectoryIfNeeded()
            let data = try makeEncoder().encode(report)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            AppLog.error("写入退出保护诊断文件失败: \(error)")
            return false
        }
    }

    /// 确保诊断文件所在目录已经存在。
    private func createDirectoryIfNeeded() throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    /// 构造读取诊断文件所需的解码器。
    /// - Returns: 使用 ISO8601 日期策略的解码器。
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// 构造写入诊断文件所需的编码器。
    /// - Returns: 适合人类阅读的 JSON 编码器。
    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// 判断当前读取失败是否只是因为诊断文件尚未生成。
    /// - Parameter error: 读取时抛出的错误对象。
    /// - Returns: 是否属于首次运行的文件缺失。
    private func isMissingFile(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain &&
            nsError.code == NSFileReadNoSuchFileError
    }
}

final class QuitGuardTelemetry: QuitGuardTelemetryWriting {
    private let store: QuitGuardDiagnosticPersisting
    private let maxEntries: Int

    init(
        store: QuitGuardDiagnosticPersisting = QuitGuardDiagnosticStore(),
        maxEntries: Int = 20
    ) {
        self.store = store
        self.maxEntries = maxEntries
    }

    /// 记录一次退出保护遥测事件，并同步写入统一日志和本地诊断文件。
    /// - Parameters:
    ///   - event: 当前要记录的事件名。
    ///   - snapshot: 与事件对应的诊断快照。
    func record(event: QuitGuardTelemetryEvent, snapshot: QuitGuardDiagnosticSnapshot) {
        log(event: event, snapshot: snapshot)
        let report = makeReport(entry: QuitGuardTelemetryEntry(event: event, snapshot: snapshot))
        _ = store.saveReport(report)
    }

    /// 构造写回磁盘的完整诊断报告。
    /// - Parameter entry: 本次要追加的诊断事件。
    /// - Returns: 截断历史后的完整诊断报告。
    private func makeReport(entry: QuitGuardTelemetryEntry) -> QuitGuardDiagnosticReport {
        let existingEntries = store.loadReport()?.entries ?? []
        let entries = Array((existingEntries + [entry]).suffix(maxEntries))
        return QuitGuardDiagnosticReport(
            latestEvent: entry.event,
            latestSnapshot: entry.snapshot,
            entries: entries
        )
    }

    /// 把退出保护事件按统一格式写入系统日志。
    /// - Parameters:
    ///   - event: 当前事件名。
    ///   - snapshot: 当前诊断快照。
    private func log(event: QuitGuardTelemetryEvent, snapshot: QuitGuardDiagnosticSnapshot) {
        let message = makeLogMessage(event: event, snapshot: snapshot)
        snapshot.suspectedFailureReason == .none ? AppLog.info(message) : AppLog.error(message)
    }

    /// 生成统一日志所需的结构化文本。
    /// - Parameters:
    ///   - event: 当前事件名。
    ///   - snapshot: 当前诊断快照。
    /// - Returns: 便于检索的日志文本。
    private func makeLogMessage(
        event: QuitGuardTelemetryEvent,
        snapshot: QuitGuardDiagnosticSnapshot
    ) -> String {
        "quitGuard event=\(event.rawValue), suspected=\(snapshot.suspectedFailureReason.rawValue), signature=\(snapshot.codeSignatureStatus.rawValue), sandbox=\(snapshot.declaredSandboxState.rawValue), tapEnabled=\(snapshot.tapSnapshot.isEnabled), tapFailure=\(snapshot.tapSnapshot.lastFailureReason?.rawValue ?? "none"), bundlePath=\(snapshot.bundlePath)"
    }
}

final class QuitGuardDiagnosticService: QuitGuardDiagnosing {
    typealias ProcessIdentifierProviding = () -> Int32
    typealias BundleInfoProviding = () -> QuitGuardBundleInfo
    typealias CodeSignatureReading = (String) -> CodeSignatureStatus
    typealias SandboxStateReading = (String) -> DeclaredSandboxState
    typealias DateProviding = () -> Date

    private let processIdentifierProvider: ProcessIdentifierProviding
    private let bundleInfoProvider: BundleInfoProviding
    private let codeSignatureReader: CodeSignatureReading
    private let sandboxStateReader: SandboxStateReading
    private let dateProvider: DateProviding

    init(
        processIdentifierProvider: @escaping ProcessIdentifierProviding = {
            ProcessInfo.processInfo.processIdentifier
        },
        bundleInfoProvider: @escaping BundleInfoProviding = QuitGuardDiagnosticService.defaultBundleInfo,
        codeSignatureReader: @escaping CodeSignatureReading = QuitGuardDiagnosticService.defaultCodeSignatureReader,
        sandboxStateReader: @escaping SandboxStateReading = QuitGuardDiagnosticService.defaultSandboxStateReader,
        dateProvider: @escaping DateProviding = Date.init
    ) {
        self.processIdentifierProvider = processIdentifierProvider
        self.bundleInfoProvider = bundleInfoProvider
        self.codeSignatureReader = codeSignatureReader
        self.sandboxStateReader = sandboxStateReader
        self.dateProvider = dateProvider
    }

    /// 基于权限、tap 与环境信息生成完整的退出保护诊断快照。
    /// - Parameters:
    ///   - availability: 当前权限快照。
    ///   - tapSnapshot: 当前 tap 运行快照。
    /// - Returns: 可用于判断和落盘的诊断结果。
    func makeSnapshot(
        availability: QuitGuardAvailability,
        tapSnapshot: TapSnapshot
    ) -> QuitGuardDiagnosticSnapshot {
        let environmentSnapshot = makeEnvironmentSnapshot()
        let permissionSnapshot = PermissionSnapshot(
            isAccessibilityTrusted: availability.isAccessibilityTrusted,
            hasListenEventAccess: availability.hasListenEventAccess
        )
        return QuitGuardDiagnosticSnapshot(
            pid: environmentSnapshot.pid,
            bundlePath: environmentSnapshot.bundlePath,
            bundleIdentifier: environmentSnapshot.bundleIdentifier,
            permissionSnapshot: permissionSnapshot,
            tapSnapshot: tapSnapshot,
            codeSignatureStatus: environmentSnapshot.codeSignatureStatus,
            declaredSandboxState: environmentSnapshot.declaredSandboxState,
            hasInvalidEntitlements: environmentSnapshot.hasInvalidEntitlements,
            hasKnownUnsupportedEnvironment: environmentSnapshot.hasKnownUnsupportedEnvironment,
            suspectedFailureReason: makeSuspectedFailureReason(
                permissionSnapshot: permissionSnapshot,
                tapSnapshot: tapSnapshot,
                environmentSnapshot: environmentSnapshot
            ),
            timestamp: dateProvider()
        )
    }

    /// 构造当前进程对应的环境快照。
    /// - Returns: 可用于分析签名与沙箱状态的环境信息。
    private func makeEnvironmentSnapshot() -> EnvironmentSnapshot {
        let bundleInfo = bundleInfoProvider()
        let codeSignatureStatus = codeSignatureReader(bundleInfo.bundlePath)
        let sandboxState = sandboxStateReader(bundleInfo.bundlePath)
        let hasInvalidEntitlements = codeSignatureStatus == .invalid && sandboxState == .unknown
        return EnvironmentSnapshot(
            pid: processIdentifierProvider(),
            bundlePath: bundleInfo.bundlePath,
            bundleIdentifier: bundleInfo.bundleIdentifier,
            codeSignatureStatus: codeSignatureStatus,
            declaredSandboxState: sandboxState,
            hasInvalidEntitlements: hasInvalidEntitlements,
            hasKnownUnsupportedEnvironment: hasInvalidEntitlements ||
                codeSignatureStatus == .invalid ||
                sandboxState == .enabled
        )
    }

    /// 按当前权限、tap 和环境状态推导最可疑的失效原因。
    /// - Parameters:
    ///   - permissionSnapshot: 当前权限快照。
    ///   - tapSnapshot: 当前 tap 快照。
    ///   - environmentSnapshot: 当前环境快照。
    /// - Returns: 最适合驱动运行编排的失效原因。
    private func makeSuspectedFailureReason(
        permissionSnapshot: PermissionSnapshot,
        tapSnapshot: TapSnapshot,
        environmentSnapshot: EnvironmentSnapshot
    ) -> SuspectedFailureReason {
        if !permissionSnapshot.isAccessibilityTrusted { return .missingAccessibility }
        if !permissionSnapshot.hasListenEventAccess { return .missingListenEvent }
        if environmentSnapshot.codeSignatureStatus == .invalid { return .invalidCodeSignature }
        if environmentSnapshot.declaredSandboxState == .enabled &&
            tapSnapshot.lastFailureReason == .tapCreateReturnedNil { return .declaredSandboxButUnavailable }
        if tapSnapshot.lastFailureReason == .tapDisabledBySystem { return .tapDisabledBySystem }
        if tapSnapshot.lastFailureReason == .tapCreateReturnedNil { return .tapCreateReturnedNil }
        return tapSnapshot.lastFailureReason == nil ? .none : .unknown
    }

    /// 读取当前应用的 bundle 路径与标识符。
    /// - Returns: 当前进程对应的 bundle 信息。
    private static func defaultBundleInfo() -> QuitGuardBundleInfo {
        QuitGuardBundleInfo(
            bundlePath: Bundle.main.bundleURL.path,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "unknown"
        )
    }

    /// 校验当前应用 bundle 的代码签名是否仍然有效。
    /// - Parameter bundlePath: 当前应用 bundle 路径。
    /// - Returns: 代码签名的有效性结果。
    private static func defaultCodeSignatureReader(bundlePath: String) -> CodeSignatureStatus {
        guard let staticCode = makeStaticCode(bundlePath: bundlePath) else { return .unavailable }
        let status = SecStaticCodeCheckValidity(staticCode, SecCSFlags(), nil)
        return status == errSecSuccess ? .valid : .invalid
    }

    /// 读取当前应用是否声明了 App Sandbox。
    /// - Parameter bundlePath: 当前应用 bundle 路径。
    /// - Returns: 签名中声明的 sandbox 状态。
    private static func defaultSandboxStateReader(bundlePath: String) -> DeclaredSandboxState {
        guard let info = makeSigningInfo(bundlePath: bundlePath) else { return .unknown }
        guard let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any] else {
            return .unknown
        }
        guard let value = entitlements["com.apple.security.app-sandbox"] as? Bool else {
            return .disabled
        }
        return value ? .enabled : .disabled
    }

    /// 构造供 Security 框架读取签名信息的静态代码对象。
    /// - Parameter bundlePath: 当前应用 bundle 路径。
    /// - Returns: 可用于后续签名校验的静态代码对象。
    private static func makeStaticCode(bundlePath: String) -> SecStaticCode? {
        var staticCode: SecStaticCode?
        let url = URL(fileURLWithPath: bundlePath) as CFURL
        let status = SecStaticCodeCreateWithPath(url, SecCSFlags(), &staticCode)
        guard status == errSecSuccess else { return nil }
        return staticCode
    }

    /// 读取当前应用签名里携带的附加信息。
    /// - Parameter bundlePath: 当前应用 bundle 路径。
    /// - Returns: Security 框架返回的签名信息字典。
    private static func makeSigningInfo(bundlePath: String) -> [String: Any]? {
        guard let staticCode = makeStaticCode(bundlePath: bundlePath) else { return nil }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        let status = SecCodeCopySigningInformation(staticCode, flags, &info)
        guard status == errSecSuccess else { return nil }
        return info as? [String: Any]
    }
}
