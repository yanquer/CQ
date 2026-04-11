//
//  NoAccessView.swift
//  CQ
//
//  用来展示退出保护缺失的授权项，并提供打开辅助功能设置、
//  请求事件监听权限与重启应用的入口，避免用户不知道 Cmd+Q 为什么没有被拦截。
//

import Foundation
import SwiftUI

struct NoAccessView: View {
    let availability: QuitGuardAvailability
    let openAccessSettings: () -> Void
    let requestListenEventAccess: () -> Void
    let restartAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(availability.headlineText)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Text(availability.messageText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !availability.missingPermissions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(availability.missingPermissions, id: \.rawValue) { permission in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(permission.title)
                                .font(.system(size: 14, weight: .semibold))
                            Text(permission.detailText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                if availability.requiresAccessibilityPermission {
                    Button("打开辅助功能设置", action: openAccessSettings)
                }
                if availability.requiresListenEventPermission {
                    Button("请求事件监听权限", action: requestListenEventAccess)
                }
                Button("重启", action: restartAction)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 360, alignment: .leading)
    }
}

extension NoAccessView {
    /// 打开授权窗口，并把当前授权视图嵌入其中。
    /// - Parameters:
    ///   - title: 窗口标题。
    ///   - sender: 触发打开动作的对象。
    /// - Returns: 创建好的窗口实例。
    func openInWindow(title: String, sender: Any?) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: self))
        window.title = title
        window.makeKeyAndOrderFront(sender)
        window.orderFrontRegardless()
        return window
    }
}
