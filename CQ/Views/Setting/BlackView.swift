//
//  BlackView.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/4.
//

import Foundation
import SwiftUI

struct WhitelistSection: View {
    @ObservedObject var model: MenuPanelModel

    var body: some View {
        MenuPanelCard(
            title: "白名单",
            subtitle: subtitleText
        ) {
            VStack(spacing: 14) {
                listContent
                HStack(spacing: 10) {
                    MenuInlineActionButton(
                        title: "添加应用",
                        systemImage: "plus",
                        kind: .secondary,
                        isDisabled: false,
                        action: model.addWhitelistApp
                    )
                    MenuInlineActionButton(
                        title: "移除所选",
                        systemImage: "minus",
                        kind: .primary,
                        isDisabled: model.selectedWhitelistItem == nil,
                        action: model.removeSelectedWhitelistItem
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension WhitelistSection {
    var subtitleText: String {
        model.whitelistItems.isEmpty
        ? "放行后不会触发二次确认，适合你明确不想拦截的应用。"
        : "当前已放行 \(model.whitelistItems.count) 个应用，点击条目后可直接移除。"
    }

    @ViewBuilder
    var listContent: some View {
        if model.whitelistItems.isEmpty {
            MenuWhitelistEmptyState()
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(model.whitelistItems, id: \.self) { item in
                        MenuWhitelistRow(
                            path: item,
                            isSelected: model.selectedWhitelistItem == item
                        ) {
                            model.selectWhitelistItem(item)
                        }
                    }
                }
            }
            .frame(height: MenuPanelStyle.whitelistViewportHeight)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MenuPanelStyle.cardOverlay, lineWidth: 1)
            )
        }
    }
}

struct MenuWhitelistRow: View {
    let path: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? MenuPanelStyle.selectedControlFill : Color.white.opacity(0.05))
                    .frame(width: 42, height: 42)
                    .overlay(icon)
                VStack(alignment: .leading, spacing: 4) {
                    Text(appName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MenuPanelStyle.textPrimary)
                        .lineLimit(1)
                    Text(path)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(MenuPanelStyle.textMuted)
                        .lineLimit(2)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(MenuPanelStyle.accent)
                }
            }
            .padding(12)
            .background(rowBackground)
        }
        .buttonStyle(.plain)
    }
}

private extension MenuWhitelistRow {
    var appName: String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }

    var icon: some View {
        Image(systemName: "app.fill")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(MenuPanelStyle.textPrimary)
    }

    var rowBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isSelected ? MenuPanelStyle.accentSoft.opacity(0.55) : Color.white.opacity(0.02))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? MenuPanelStyle.accent.opacity(0.8) : MenuPanelStyle.cardOverlay, lineWidth: 1)
            )
    }
}

struct MenuWhitelistEmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MenuPanelStyle.accent)
            Text("还没有放行应用")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MenuPanelStyle.textPrimary)
            Text("需要跳过二次确认的应用，可以在这里直接添加。")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MenuPanelStyle.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: MenuPanelStyle.whitelistViewportHeight)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MenuPanelStyle.cardOverlay, lineWidth: 1)
        )
    }
}

#Preview {
    WhitelistSection(model: MenuPanelModel())
}
