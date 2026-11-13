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
    let addAppAction: () -> Void

    /// 复用白名单内容，并将选择窗口的打开动作交给当前宿主界面。
    init(model: MenuPanelModel, addAppAction: (() -> Void)? = nil) {
        self.model = model
        self.addAppAction = addAppAction ?? model.addWhitelistApp
    }

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
                if let error = model.whitelistError, !model.whitelistReadFailed || !model.whitelistItems.isEmpty {
                    Text(error)
                        .font(MenuPanelStyle.helperFont)
                        .foregroundStyle(MenuPanelStyle.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if model.whitelistReadFailed {
                    Button("重新读取", action: model.reloadWhitelist)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .help("重新读取磁盘中的白名单")
                }
                HStack(spacing: MenuPanelStyle.whitelistButtonSpacing) {
                    MenuInlineActionButton(
                        title: "移除所选",
                        systemImage: "minus",
                        kind: .secondary,
                        isDisabled: model.selectedWhitelistItem == nil,
                        action: model.removeSelectedWhitelistItem
                    )
                    MenuInlineActionButton(
                        title: "添加应用",
                        systemImage: "plus",
                        kind: .primary,
                        isDisabled: model.isShowingAppPicker,
                        action: addAppAction
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
        if model.whitelistReadFailed && model.whitelistItems.isEmpty {
            MenuWhitelistEmptyState(
                systemImage: "exclamationmark.triangle",
                title: "白名单读取失败",
                subtitle: model.whitelistError ?? "可点击“重新读取”重试。"
            )
        } else if model.whitelistItems.isEmpty {
            MenuWhitelistEmptyState()
        } else if model.filteredWhitelistItems.isEmpty {
            MenuWhitelistEmptyState(
                systemImage: "magnifyingglass",
                title: "没有匹配结果",
                subtitle: "换个应用名或路径关键词试试。"
            )
        } else {
            MenuListViewport {
                ScrollView(.vertical) {
                    LazyVStack(spacing: MenuPanelStyle.whitelistListSpacing) {
                        ForEach(model.filteredWhitelistItems, id: \.self) { item in
                            MenuWhitelistRow(
                                name: model.whitelistAppName(for: item),
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

/// 为按键处理保存搜索框所在窗口的弱引用，并同步读取组字状态。
@MainActor
private final class MenuSearchInputContext {
    weak var anchor: NSView?

    /// 仅接管无编辑修饰键、且文本输入系统未处于组字中的方向键。
    func canMoveSelection(modifiers: EventModifiers) -> Bool {
        guard modifiers.intersection([.command, .control, .option, .shift]).isEmpty,
              let editor = anchor?.window?.firstResponder as? NSTextInputClient else { return false }
        return !editor.hasMarkedText()
    }
}

/// 将输入上下文定位到搜索框所在窗口，保持原有 SwiftUI 文本框的编辑与焦点行为。
private struct MenuSearchInputAnchor: NSViewRepresentable {
    let inputContext: MenuSearchInputContext

    /// 创建不绘制内容的局部锚点，供按键处理同步读取所在窗口。
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        inputContext.anchor = view
        return view
    }

    /// 窗口归属由 AppKit 随锚点的视图生命周期维护。
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct MenuWhitelistSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var inputContext = MenuSearchInputContext()
    let placeholder: String
    let focusesOnAppear: Bool
    let moveSelection: ((Int) -> Void)?

    /// 创建带清空操作的搜索框，并允许应用选择器打开时自动聚焦。
    init(
        text: Binding<String>,
        placeholder: String = "搜索应用名或路径",
        focusesOnAppear: Bool = false,
        moveSelection: ((Int) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.focusesOnAppear = focusesOnAppear
        self.moveSelection = moveSelection
    }

    var body: some View {
        HStack(spacing: MenuPanelStyle.whitelistSearchSpacing) {
            Image(systemName: "magnifyingglass")
                .font(MenuPanelStyle.whitelistSearchIconFont)
                .foregroundStyle(MenuPanelStyle.textMuted)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(MenuPanelStyle.textPrimary)
                .focused($isFocused)
                .accessibilityLabel(placeholder)
                .background {
                    MenuSearchInputAnchor(inputContext: inputContext)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .onKeyPress(keys: [.downArrow, .upArrow]) { press in
                    guard let moveSelection,
                          inputContext.canMoveSelection(modifiers: press.modifiers) else {
                        return .ignored
                    }
                    moveSelection(press.key == .downArrow ? 1 : -1)
                    return .handled
                }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MenuPanelStyle.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
                .help("清空搜索")
            }
        }
        .padding(.horizontal, MenuPanelStyle.whitelistSearchHorizontalPadding)
        .padding(.vertical, MenuPanelStyle.whitelistSearchVerticalPadding)
        .background(searchBackground)
        .onAppear {
            if focusesOnAppear { isFocused = true }
        }
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
    }
}

struct MenuWhitelistRow: View {
    let name: String
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
                    Text(name)
                        .font(MenuPanelStyle.whitelistRowTitleFont)
                        .foregroundStyle(MenuPanelStyle.textPrimary)
                        .lineLimit(1)
                    Text(path)
                        .font(MenuPanelStyle.whitelistRowPathFont)
                        .foregroundStyle(MenuPanelStyle.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(path)
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
        .accessibilityLabel(name)
        .accessibilityValue(isSelected ? "已选中" : "未选中")
        .accessibilityHint(path)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help("\(name)\n\(path)")
    }
}

private extension MenuWhitelistRow {
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
                    placeholder: "搜索应用名或路径",
                    focusesOnAppear: true,
                    moveSelection: model.moveAppPickerSelection
                )
                .onSubmit(model.confirmAppPickerSelection)
                listContent
                if let error = model.whitelistError {
                    Text(error)
                        .font(MenuPanelStyle.helperFont)
                        .foregroundStyle(MenuPanelStyle.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if model.whitelistReadFailed {
                    Button("重新读取白名单", action: model.reloadWhitelist)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: MenuPanelStyle.whitelistButtonSpacing) {
                    Button("浏览…", action: model.addWhitelistAppFromFinder)
                        .buttonStyle(.borderless)
                        .help("从 Finder 选择其他位置的应用")
                    if model.appPickerLoadError != nil {
                        Button("重新加载", action: model.reloadAppPicker)
                            .buttonStyle(.borderless)
                    }
                    Spacer()
                    Button("取消", action: model.dismissAppPicker)
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.cancelAction)
                    Button("添加", action: model.confirmAppPickerSelection)
                        .buttonStyle(.borderedProminent)
                        .tint(MenuPanelStyle.accent)
                        .disabled(!model.canConfirmAppPickerSelection)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onExitCommand(perform: model.dismissAppPicker)
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
        } else if model.appPickerItems.isEmpty && model.appPickerLoadError != nil {
            MenuWhitelistEmptyState(
                systemImage: "exclamationmark.triangle",
                title: "应用列表加载失败",
                subtitle: "点击“重新加载”重试，或使用“浏览…”选择应用。"
            )
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
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: MenuPanelStyle.whitelistListSpacing) {
                            ForEach(model.filteredAppPickerItems) { item in
                                MenuWhitelistRow(
                                    name: item.name,
                                    path: item.path,
                                    isSelected: model.selectedAppPickerItem == item
                                ) {
                                    model.selectAppPickerItem(item)
                                }
                            }
                        }
                    }
                    .onChange(of: model.selectedAppPickerItem) { _, item in
                        if let item { proxy.scrollTo(item.id) }
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
    }
}

#Preview {
    WhitelistSection(model: MenuPanelModel())
}
