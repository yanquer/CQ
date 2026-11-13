//
//  TipView.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/9.
//

import Foundation
import AppKit
import SwiftUI

/// 保存本次提示对应的应用信息，确认过期时继续使用同一份展示内容。
struct TipApplication: Equatable {
    let name: String
    let icon: NSImage?

    /// 只解析按键时记录的目标进程和路径，避免异步展示时读取另一前台应用。
    static func resolve(_ application: QuitGuardApplication?) -> TipApplication? {
        guard let application else {
            AppLog.error("Tip application lookup unavailable: reason=missingTargetApplication")
            return nil
        }
        let runningApplication = NSRunningApplication(processIdentifier: application.processIdentifier)
        let target = runningApplication.flatMap { app in
            application.bundlePath == nil || app.bundleURL?.path == application.bundlePath ? app : nil
        }
        if let path = application.bundlePath, FileManager.default.fileExists(atPath: path) {
            return TipApplication(
                name: AppPickerItem(url: URL(fileURLWithPath: path)).name,
                icon: target?.icon ?? NSWorkspace.shared.icon(forFile: path)
            )
        }
        if let name = target?.localizedName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return TipApplication(name: name, icon: target?.icon)
        }
        AppLog.error("Tip application lookup unavailable: pid=\(application.processIdentifier), reason=targetMetadataUnavailable")
        return TipApplication(name: "应用名称不可用（PID \(application.processIdentifier)）", icon: nil)
    }
}

struct TipPresentation: Equatable, Identifiable {
    let id = UUID()
    let prompt: QuitPrompt
    let duration: TimeInterval
    var application: TipApplication? = nil
}

final class TipOverlayModel: ObservableObject {
    @Published private(set) var presentation: TipPresentation
    @Published private(set) var isVisible = false
    private var visibilityID = UUID()
    private var confirmationExpiryWorkItem: DispatchWorkItem?

    init(presentation: TipPresentation) {
        self.presentation = presentation
    }

    /// 创建可见的预览模型，供画布持续核对指定提示样式。
    static func preview(presentation: TipPresentation) -> TipOverlayModel {
        let model = TipOverlayModel(presentation: presentation)
        model.isVisible = true
        return model
    }

    /// 显示新提示并隔离异步入场动画，关闭后的旧动画不能重新显示提示。
    func present(
        prompt: QuitPrompt,
        duration: TimeInterval,
        application: TipApplication? = nil,
        animateIn: Bool
    ) {
        visibilityID = UUID()
        let expectedVisibilityID = visibilityID
        presentation = TipPresentation(prompt: prompt, duration: duration, application: application)
        scheduleConfirmationExpiry(prompt)
        guard animateIn else {
            isVisible = true
            return
        }

        isVisible = false
        DispatchQueue.main.async { [weak self] in
            guard let self, self.visibilityID == expectedVisibilityID else { return }
            self.isVisible = true
        }
    }

    /// 隐藏提示并使尚未执行的入场动画失效。
    func dismiss() {
        visibilityID = UUID()
        confirmationExpiryWorkItem?.cancel()
        confirmationExpiryWorkItem = nil
        isVisible = false
    }

    /// 确认时限结束后保留停留中的提示，但不再宣称下一次按键可以直接退出。
    private func scheduleConfirmationExpiry(_ prompt: QuitPrompt) {
        confirmationExpiryWorkItem?.cancel()
        confirmationExpiryWorkItem = nil
        guard case .confirmExit(let window) = prompt else { return }
        let expectedVisibilityID = visibilityID
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.visibilityID == expectedVisibilityID else { return }
            self.presentation = TipPresentation(
                prompt: .confirmationExpired,
                duration: self.presentation.duration,
                application: self.presentation.application
            )
            self.confirmationExpiryWorkItem = nil
        }
        confirmationExpiryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, window), execute: workItem)
    }

    /// 释放提示模型时撤销过期任务。
    deinit {
        confirmationExpiryWorkItem?.cancel()
    }
}

struct TipView: View {
    @ObservedObject var model: TipOverlayModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.clear

            TipCardView(presentation: model.presentation)
                .id(model.presentation.id)
                .scaleEffect(model.isVisible ? 1 : 0.96)
                .opacity(model.isVisible ? 1 : 0)
                .animation(transitionAnimation, value: model.isVisible)
        }
        .frame(width: TipViewSize.width, height: TipViewSize.height)
        .preferredColorScheme(.dark)
        .allowsHitTesting(false)
    }
}

private extension TipView {
    var transitionAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.9)
    }
}

private struct TipCardView: View {
    let presentation: TipPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                applicationIcon

                VStack(alignment: .leading, spacing: 6) {
                    Text(presentation.application?.name ?? "目标应用信息不可用")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MenuPanelStyle.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(presentation.prompt.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(MenuPanelStyle.textPrimary)
                        .lineLimit(1)

                    Text(presentation.prompt.message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MenuPanelStyle.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if presentation.prompt.showsProgress {
                HStack(spacing: 8) {
                    Text("提示停留")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(MenuPanelStyle.textSecondary)
                        .fixedSize()
                    TipProgressBar(duration: presentation.duration)
                        .accessibilityLabel("提示窗口停留时间")
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: TipViewSize.width, alignment: .leading)
        .background(cardBackground)
        .overlay(cardStroke)
        .shadow(color: MenuPanelStyle.shadow.opacity(0.9), radius: 22, x: 0, y: 14)
        .accessibilityElement(children: .combine)
    }
}

private extension TipCardView {
    var applicationIcon: some View {
        Group {
            if let icon = presentation.application?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(MenuPanelStyle.textSecondary)
            }
        }
        .frame(width: 46, height: 46)
        .accessibilityHidden(true)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(MenuPanelStyle.chromeFill)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.screen)
            }
    }

    var cardStroke: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(MenuPanelStyle.cardOverlay.opacity(1.15), lineWidth: 1)
    }
}

private struct TipProgressBar: View {
    let duration: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            Capsule(style: .continuous)
                .fill(MenuPanelStyle.controlFill)
                .overlay(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(progressTint)
                        .frame(width: max(6, proxy.size.width * progress))
                }
        }
        .frame(height: 3)
        .onAppear(perform: startProgressAnimation)
    }
}

private extension TipProgressBar {
    var progressTint: some ShapeStyle {
        LinearGradient(
            colors: [
                MenuPanelStyle.accent,
                MenuPanelStyle.selectedControlFill
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    func startProgressAnimation() {
        guard !reduceMotion, duration > 0 else {
            progress = 1
            return
        }

        progress = 1
        withAnimation(.linear(duration: duration)) {
            progress = 0
        }
    }
}

#Preview("确认退出") {
    TipView(
        model: TipOverlayModel.preview(
            presentation: TipPresentation(
                prompt: .confirmExit(window: 3),
                duration: 0, // 固定预览进度条，持续展示确认样式。
                application: TipApplication(name: "Safari 浏览器", icon: NSImage(systemSymbolName: "safari", accessibilityDescription: nil))
            )
        )
    )
}

#Preview("长按透传") {
    TipView(
        model: TipOverlayModel.preview(
            presentation: TipPresentation(
                prompt: .forwardedLongPress,
                duration: 0,
                application: TipApplication(name: "Google Chrome", icon: NSImage(systemSymbolName: "globe", accessibilityDescription: nil))
            )
        )
    )
}
