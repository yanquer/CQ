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
            MenuListViewport {
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
            }
        }
    }
}

struct MenuWhitelistSearchField: View {
    @Binding var text: String
    let placeholder: String

    init(
        text: Binding<String>,
        placeholder: String = "搜索应用名或路径"
    ) {
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        HStack(spacing: MenuPanelStyle.whitelistSearchSpacing) {
            Image(systemName: "magnifyingglass")
                .font(MenuPanelStyle.whitelistSearchIconFont)
                .foregroundStyle(MenuPanelStyle.textMuted)
            TextField(placeholder, text: $text)
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

struct MenuListViewport<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
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

struct MenuAppPickerOverlay: View {
    @ObservedObject var model: MenuPanelModel

    var body: some View {
        if model.isShowingAppPicker {
            ZStack {
                Color.black.opacity(0.42)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.dismissAppPicker()
                    }
                MenuAppPickerSheet(model: model)
                    .padding(14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: MenuPanelStyle.cornerRadius,
                    style: .continuous
                )
            )
        }
    }
}

struct MenuAppPickerSheet: View {
    @ObservedObject var model: MenuPanelModel

    var body: some View {
        MenuPanelCard(
            title: "选择应用",
            subtitle: model.appPickerSubtitleText
        ) {
            VStack(spacing: MenuPanelStyle.whitelistSectionSpacing) {
                MenuWhitelistSearchField(
                    text: $model.appPickerSearchText,
                    placeholder: "搜索应用名或路径"
                )
                listContent
                HStack(spacing: MenuPanelStyle.whitelistButtonSpacing) {
                    MenuInlineActionButton(
                        title: "从 Finder 选择",
                        systemImage: "folder",
                        kind: .secondary,
                        isDisabled: false,
                        action: model.addWhitelistAppFromFinder
                    )
                    MenuInlineActionButton(
                        title: "取消",
                        systemImage: "xmark",
                        kind: .secondary,
                        isDisabled: false,
                        action: model.dismissAppPicker
                    )
                    MenuInlineActionButton(
                        title: "添加到白名单",
                        systemImage: "checkmark",
                        kind: .primary,
                        isDisabled: !model.canConfirmAppPickerSelection,
                        action: model.confirmAppPickerSelection
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private extension MenuAppPickerSheet {
    @ViewBuilder
    var listContent: some View {
        if model.isLoadingAppPicker {
            MenuListViewport {
                VStack(spacing: MenuPanelStyle.emptyStateSpacing) {
                    ProgressView()
                        .tint(MenuPanelStyle.accent)
                    Text("正在加载应用列表")
                        .font(MenuPanelStyle.whitelistEmptyTitleFont)
                        .foregroundStyle(MenuPanelStyle.textPrimary)
                }
                .frame(maxWidth: .infinity, minHeight: MenuPanelStyle.whitelistViewportHeight)
            }
        } else if model.appPickerItems.isEmpty {
            MenuWhitelistEmptyState(
                systemImage: "app.badge.plus",
                title: "没有找到应用",
                subtitle: "稍后再试，或者直接从 Finder 里手动选择。"
            )
        } else if model.filteredAppPickerItems.isEmpty {
            MenuWhitelistEmptyState(
                systemImage: "magnifyingglass",
                title: "没有匹配结果",
                subtitle: "换个应用名或路径关键词试试。"
            )
        } else {
            MenuListViewport {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: MenuPanelStyle.whitelistListSpacing) {
                        ForEach(model.filteredAppPickerItems) { item in
                            MenuWhitelistRow(
                                path: item.path,
                                isSelected: model.selectedAppPickerItem == item
                            ) {
                                model.selectAppPickerItem(item)
                            }
                        }
                    }
                }
            }
        }
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
