//
//  TipView.swift
//  CQ
//
//  Created by 烟雀 on 2023/12/9.
//

import Foundation
import SwiftUI

struct TipPresentation: Equatable, Identifiable {
    let id = UUID()
    let prompt: QuitPrompt
    let duration: TimeInterval
}

final class TipOverlayModel: ObservableObject {
    @Published private(set) var presentation: TipPresentation
    @Published private(set) var isVisible = false
    private var visibilityID = UUID()
    private var confirmationExpiryWorkItem: DispatchWorkItem?

    init(presentation: TipPresentation) {
        self.presentation = presentation
    }

    /// 显示新提示并隔离异步入场动画，关闭后的旧动画不能重新显示提示。
    func present(
        prompt: QuitPrompt,
        duration: TimeInterval,
        animateIn: Bool
    ) {
        visibilityID = UUID()
        let expectedVisibilityID = visibilityID
        presentation = TipPresentation(prompt: prompt, duration: duration)
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
            self.presentation = TipPresentation(prompt: .confirmationExpired, duration: self.presentation.duration)
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
                leadingBadge

                VStack(alignment: .leading, spacing: 6) {
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
    var leadingBadge: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(badgeFill)
            .frame(width: 46, height: 46)
            .overlay {
                if let badgeText = presentation.prompt.badgeText {
                    Text(badgeText)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(MenuPanelStyle.textPrimary)
                } else {
                    Image(systemName: presentation.prompt.symbolName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MenuPanelStyle.textPrimary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MenuPanelStyle.cardOverlay.opacity(1.1), lineWidth: 1)
            )
    }

    var badgeFill: some ShapeStyle {
        switch presentation.prompt {
        case .confirmExit:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        MenuPanelStyle.selectedControlFill,
                        MenuPanelStyle.accentSoft
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .forwardedLongPress, .confirmationExpired:
            return AnyShapeStyle(MenuPanelStyle.controlFill)
        }
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
        model: TipOverlayModel(
            presentation: TipPresentation(
                prompt: .confirmExit(window: 3),
                duration: 3
            )
        )
    )
}

#Preview("长按透传") {
    TipView(
        model: TipOverlayModel(
            presentation: TipPresentation(
                prompt: .forwardedLongPress,
                duration: 1
            )
        )
    )
}
