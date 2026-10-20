//
//  MenuView.swift
//  CQ
//
//  Created by 烟雀 on 2024/1/2.
//

import Foundation
import SwiftUI
import ServiceManagement

struct GeneralSettingsSection: View {
    @ObservedObject var model: MenuPanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPanelStyle.sectionSpacing) {
            MenuPanelCard(
                title: "启动行为",
                subtitle: "此项更改立即生效。"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    MenuSettingToggleRow(
                        title: "登录时启动",
                        subtitle: "启动后常驻菜单栏。",
                        isOn: Binding(
                            get: { model.startAtLogin },
                            set: model.toggleLaunchAtLogin
                        )
                    )
                    if let message = model.autoLaunchMessage {
                        Text(message)
                            .font(MenuPanelStyle.helperFont)
                            .foregroundStyle(MenuPanelStyle.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if model.loginStatus == .requiresApproval {
                        Button("打开登录项设置", action: SMAppService.openSystemSettingsLoginItems)
                            .buttonStyle(.bordered)
                    }
                }
            }

            MenuPanelCard(
                title: "退出保护行为",
                subtitle: "以下两项时间设置需点击“应用更改”保存。"
            ) {
                VStack(spacing: MenuPanelStyle.settingGroupSpacing) {
                    MenuSettingSliderRow(
                        title: "再次按键时限",
                        subtitle: "在此时间内再按 Cmd+Q 即可退出。",
                        value: $model.doubleTapIntervalDraft
                    )
                    MenuSettingSliderRow(
                        title: "提示停留时间",
                        subtitle: "只影响提示显示，不改变确认时限。",
                        value: $model.alertCloseTimeDraft
                    )
                    HStack(spacing: 12) {
                        Text(model.hasPendingChanges ? "时间设置尚未保存" : "时间设置已保存")
                            .font(MenuPanelStyle.helperFont)
                            .foregroundStyle(MenuPanelStyle.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        MenuInlineActionButton(
                            title: "应用更改",
                            systemImage: "checkmark",
                            kind: .primary,
                            isDisabled: !model.hasPendingChanges,
                            action: model.applySettings
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: model.refreshAutoLaunchStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshAutoLaunchStatus()
        }
    }
}

struct MenuSettingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: MenuPanelStyle.settingRowSpacing) {
            VStack(alignment: .leading, spacing: MenuPanelStyle.textStackSpacing) {
                Text(title)
                    .font(MenuPanelStyle.settingTitleFont)
                    .foregroundStyle(MenuPanelStyle.textPrimary)
                Text(subtitle)
                    .font(MenuPanelStyle.helperFont)
                    .foregroundStyle(MenuPanelStyle.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle(title, isOn: $isOn)
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
        VStack(alignment: .leading, spacing: MenuPanelStyle.sliderRowSpacing) {
            HStack(alignment: .top, spacing: MenuPanelStyle.sliderHeaderSpacing) {
                VStack(alignment: .leading, spacing: MenuPanelStyle.textStackSpacing) {
                    Text(title)
                        .font(MenuPanelStyle.settingTitleFont)
                        .foregroundStyle(MenuPanelStyle.textPrimary)
                    Text(subtitle)
                        .font(MenuPanelStyle.helperFont)
                        .foregroundStyle(MenuPanelStyle.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                MenuSettingValuePill(value: value)
            }
            Slider(value: $value, in: QuitGuardSettings.supportedInterval, step: 1)
                .tint(MenuPanelStyle.accent)
        }
    }
}

struct MenuSettingValuePill: View {
    let value: Double

    var body: some View {
        Text("\(Int(value)) 秒")
            .font(MenuPanelStyle.valuePillFont)
            .foregroundStyle(MenuPanelStyle.textPrimary)
            .padding(.horizontal, MenuPanelStyle.valuePillHorizontalPadding)
            .padding(.vertical, MenuPanelStyle.valuePillVerticalPadding)
            .background(
                Capsule()
                    .fill(MenuPanelStyle.selectedControlFill)
            )
    }
}

#Preview {
    GeneralSettingsSection(model: MenuPanelModel())
}
