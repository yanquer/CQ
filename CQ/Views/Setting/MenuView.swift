//
//  MenuView.swift
//  CQ
//
//  Created by 烟雀 on 2024/1/2.
//

import Foundation
import SwiftUI

struct GeneralSettingsSection: View {
    @ObservedObject var model: MenuPanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPanelStyle.sectionSpacing) {
            MenuPanelCard(
                title: "启动行为",
                subtitle: "保持常驻，但不打扰你的工作流。"
            ) {
                MenuSettingToggleRow(
                    title: "登录时启动",
                    subtitle: "打开电脑后自动进入菜单栏，减少手动启动。",
                    isOn: Binding(
                        get: { model.startAtLogin },
                        set: model.toggleLaunchAtLogin
                    )
                )
            }

            MenuPanelCard(
                title: "退出保护行为",
                subtitle: "改的是保护节奏，点击“应用更改”后才会写回配置。"
            ) {
                VStack(spacing: 16) {
                    MenuSettingSliderRow(
                        title: "CMD+Q 最长间隔时间",
                        subtitle: "两次按键在这个时长内会被视为确认退出。",
                        value: $model.doubleTapIntervalDraft
                    )
                    MenuSettingSliderRow(
                        title: "提示窗口关闭时间",
                        subtitle: "提示浮层的停留时间，适合按自己的节奏调整。",
                        value: $model.alertCloseTimeDraft
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MenuSettingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MenuPanelStyle.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MenuPanelStyle.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(MenuPanelStyle.accent)
        }
    }
}

struct MenuSettingSliderRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MenuPanelStyle.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MenuPanelStyle.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                MenuSettingValuePill(value: value)
            }
            Slider(value: $value, in: 1...8, step: 1)
                .tint(MenuPanelStyle.accent)
        }
    }
}

struct MenuSettingValuePill: View {
    let value: Double

    var body: some View {
        Text("\(Int(value)) 秒")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(MenuPanelStyle.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(MenuPanelStyle.selectedControlFill)
            )
    }
}

#Preview {
    GeneralSettingsSection(model: MenuPanelModel())
}
