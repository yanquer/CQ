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
            VStack(spacing: MenuPanelStyle.whitelistSectionSpacing) {
                if !model.whitelistItems.isEmpty {
                    MenuWhitelistSearchField(text: $model.whitelistSearchText)
                }
                listContent
                HStack(spacing: MenuPanelStyle.whitelistButtonSpacing) {
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
        model.whitelistSubtitleText
    }

    @ViewBuilder
    var listContent: some View {
        if model.whitelistItems.isEmpty {
            MenuWhitelistEmptyState()
        } else if model.filteredWhitelistItems.isEmpty {
            MenuWhitelistEmptyState(
                systemImage: "magnifyingglass",
                title: "没有匹配结果",
                subtitle: "换个应用名或路径关键词试试。"
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: MenuPanelStyle.whitelistListSpacing) {
                    ForEach(model.filteredWhitelistItems, id: \.self) { item in
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
            .padding(MenuPanelStyle.whitelistListPadding)
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

struct MenuWhitelistSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: MenuPanelStyle.whitelistSearchSpacing) {
            Image(systemName: "magnifyingglass")
                .font(MenuPanelStyle.whitelistSearchIconFont)
                .foregroundStyle(MenuPanelStyle.textMuted)
            TextField("搜索应用名或路径", text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(MenuPanelStyle.textPrimary)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MenuPanelStyle.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MenuPanelStyle.whitelistSearchHorizontalPadding)
        .padding(.vertical, MenuPanelStyle.whitelistSearchVerticalPadding)
        .background(searchBackground)
    }
}

private extension MenuWhitelistSearchField {
    var searchBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MenuPanelStyle.cardOverlay, lineWidth: 1)
            )
    }
}

struct MenuWhitelistRow: View {
    let path: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MenuPanelStyle.whitelistRowSpacing) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? MenuPanelStyle.selectedControlFill : Color.white.opacity(0.05))
                    .frame(width: MenuPanelStyle.whitelistIconSize, height: MenuPanelStyle.whitelistIconSize)
                    .overlay(icon)
                VStack(alignment: .leading, spacing: MenuPanelStyle.textStackSpacing) {
                    Text(appName)
                        .font(MenuPanelStyle.whitelistRowTitleFont)
                        .foregroundStyle(MenuPanelStyle.textPrimary)
                        .lineLimit(1)
                    Text(path)
                        .font(MenuPanelStyle.whitelistRowPathFont)
                        .foregroundStyle(MenuPanelStyle.textMuted)
                        .lineLimit(2)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(MenuPanelStyle.accent)
                }
            }
            .padding(MenuPanelStyle.whitelistRowPadding)
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
            .font(MenuPanelStyle.whitelistIconFont)
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
    let systemImage: String
    let title: String
    let subtitle: String

    init(
        systemImage: String = "checkmark.shield",
        title: String = "还没有放行应用",
        subtitle: String = "需要跳过二次确认的应用，可以在这里直接添加。"
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: MenuPanelStyle.emptyStateSpacing) {
            Image(systemName: systemImage)
                .font(MenuPanelStyle.whitelistEmptyIconFont)
                .foregroundStyle(MenuPanelStyle.accent)
            Text(title)
                .font(MenuPanelStyle.whitelistEmptyTitleFont)
                .foregroundStyle(MenuPanelStyle.textPrimary)
            Text(subtitle)
                .font(MenuPanelStyle.whitelistEmptySubtitleFont)
                .foregroundStyle(MenuPanelStyle.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: MenuPanelStyle.whitelistViewportHeight)
        .padding(.horizontal, MenuPanelStyle.emptyStateHorizontalPadding)
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
