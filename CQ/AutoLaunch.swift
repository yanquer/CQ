// 管理登录启动注册，并将系统状态和失败原因交给界面处理。
import Foundation
import ServiceManagement

/// 封装当前应用的登录启动注册，避免界面把请求成功误当成已经生效。
enum AutoLaunch {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    /// 更新登录启动注册；待用户批准的注册同样支持取消，系统错误交由调用方展示。
    static func setEnabled(_ isEnabled: Bool) throws {
        let service = SMAppService.mainApp
        if isEnabled {
            guard service.status != .enabled, service.status != .requiresApproval else { return }
            try service.register()
        } else {
            guard service.status == .enabled || service.status == .requiresApproval else { return }
            try service.unregister()
        }
        AppLog.info("Login item updated: requested=\(isEnabled), status=\(service.status.rawValue)")
    }
}
