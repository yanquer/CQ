//
//  OpenAccess.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/6.
//
// 打开辅助功能
//

import Foundation
import Cocoa

extension AppDelegate {
    static let openAccessSymbol = "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'"
    
    static func openAccessSettings(){
        _ = ShellCommand.exec(cmds: ["-c", openAccessSymbol])
    }
    
    static func hasAccess() -> Bool{
        return AXIsProcessTrusted()
    }
    
    static func hasAccessAndGain() -> Bool{
        // 自动尝试获取, 有个bug, 就是不能一直 restartCQ
        if AXIsProcessTrusted(){ return true }
        
        openAccessSettings()
        // restartCQ()
        
        return false
    }
    
    /// 确认系统成功启动新实例后再退出，启动失败时保留当前应用并提示原因。
    @MainActor
    static func restartCQ() {
        AppRelauncher.shared.restart { error in
            AppLog.error("Application relaunch failed: \(error)")
            let alert = NSAlert()
            alert.messageText = "无法重启 CQ"
            alert.informativeText = "新实例未能启动。请稍后重试，当前 CQ 将继续运行。"
            alert.runModal()
        }
    }
}

/// 通过系统启动 API 创建独立新实例，避免重启请求仅激活旧实例。
@MainActor
final class AppRelauncher {
    static let shared = AppRelauncher()
    private(set) var isRestarting = false

    typealias Completion = @MainActor (Error?) -> Void
    typealias Launcher = @MainActor (@escaping Completion) -> Void

    /// 等待新实例启动结果再决定退出；失败时向界面反馈并保留原进程。
    func restart(
        launch: Launcher = AppRelauncher.launchNewInstance,
        terminate: @escaping @MainActor () -> Void = { NSApp.terminate(nil) },
        reportFailure: @escaping @MainActor (Error) -> Void
    ) {
        guard !isRestarting else {
            AppLog.info("Relaunch already in progress; ignoring duplicate request")
            return
        }
        isRestarting = true
        launch { [self] error in
            if let error {
                isRestarting = false
                reportFailure(error)
                return
            }
            AppLog.info("New application instance launched; terminating previous instance")
            terminate()
        }
    }

    /// 构造强制启动新实例的配置，保留系统沙箱兼容性且不抢占前台焦点。
    static func makeLaunchConfiguration() -> NSWorkspace.OpenConfiguration {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = false
        return configuration
    }

    /// 打开当前应用的实际路径，并将系统回调交回主线程。
    private static func launchNewInstance(completion: @escaping Completion) {
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: makeLaunchConfiguration()
        ) { application, error in
            let failure = error ?? (application == nil
                ? NSError(domain: "CQ.Relaunch", code: 1, userInfo: [NSLocalizedDescriptionKey: "No application instance returned"])
                : nil)
            Task { @MainActor in completion(failure) }
        }
    }
}
