//
//  MenuShowView.swift
//  CQ
//
//  Created by 烟雀 on 2024/7/5.
//

import AppKit
import Combine
import Foundation
import SwiftUI

struct MenuShowView: View {
    @StateObject private var model: MenuPanelModel

    init(model: MenuPanelModel = MenuPanelModel()) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        MenuPanelScreen(
            model: model,
            size: .popover
        )
    }
}

enum MenuPanelTab: String, CaseIterable, Identifiable {
    case general = "通用"
    case whitelist = "白名单"

    var id: String {
        rawValue
    }
}

enum MenuPanelSize {
    case popover
    case expanded

    var width: CGFloat {
        switch self {
        case .popover:
            return MenuPanelStyle.popoverWidth
        case .expanded:
            return MenuPanelStyle.windowWidth
        }
    }

    var height: CGFloat {
        switch self {
        case .popover:
            return MenuPanelStyle.popoverHeight
        case .expanded:
            return MenuPanelStyle.windowHeight
        }
    }

    var outerPadding: CGFloat {
        switch self {
        case .popover:
            return MenuPanelStyle.popoverOuterPadding
        case .expanded:
            return MenuPanelStyle.expandedOuterPadding
        }
    }
}

struct MenuPanelStyle {
    static let popoverWidth: CGFloat = 416
    static let popoverHeight: CGFloat = 620
    static let windowWidth: CGFloat = 484
    static let windowHeight: CGFloat = 700
    static let whitelistViewportHeight: CGFloat = 220
    static let popoverOuterPadding: CGFloat = 16
    static let expandedOuterPadding: CGFloat = 20
    static let chromePadding: CGFloat = 8
    static let cornerRadius: CGFloat = 26
    static let cardCornerRadius: CGFloat = 20
    static let sectionSpacing: CGFloat = 12
    static let cardSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 14
    static let textStackSpacing: CGFloat = 4
    static let headerSpacing: CGFloat = 8
    static let headerTitleRowSpacing: CGFloat = 12
    static let headerIconSize: CGFloat = 48
    static let segmentedSpacing: CGFloat = 8
    static let segmentedContainerPadding: CGFloat = 6
    static let segmentedVerticalPadding: CGFloat = 8
    static let actionBarSpacing: CGFloat = 12
    static let actionButtonVerticalPadding: CGFloat = 10
    static let actionButtonHorizontalPadding: CGFloat = 12
    static let settingGroupSpacing: CGFloat = 12
    static let settingRowSpacing: CGFloat = 14
    static let sliderHeaderSpacing: CGFloat = 12
    static let sliderRowSpacing: CGFloat = 10
    static let valuePillHorizontalPadding: CGFloat = 9
    static let valuePillVerticalPadding: CGFloat = 5
    static let whitelistSectionSpacing: CGFloat = 12
    static let whitelistSearchSpacing: CGFloat = 8
    static let whitelistSearchHorizontalPadding: CGFloat = 12
    static let whitelistSearchVerticalPadding: CGFloat = 10
    static let whitelistListSpacing: CGFloat = 10
    static let whitelistListPadding: CGFloat = 8
    static let whitelistButtonSpacing: CGFloat = 10
    static let whitelistRowSpacing: CGFloat = 12
    static let whitelistRowPadding: CGFloat = 10
    static let whitelistIconSize: CGFloat = 38
    static let whitelistSearchIconFont: Font = .system(size: 12, weight: .semibold)
    static let emptyStateSpacing: CGFloat = 10
    static let emptyStateHorizontalPadding: CGFloat = 18
    static let headerTitleFont: Font = .system(size: 22, weight: .bold, design: .rounded)
    static let headerSubtitleFont: Font = .system(size: 10, weight: .medium)
    static let segmentedLabelFont: Font = .system(size: 12, weight: .semibold)
    static let cardTitleFont: Font = .system(size: 14, weight: .semibold)
    static let helperFont: Font = .system(size: 10, weight: .medium)
    static let settingTitleFont: Font = .system(size: 13, weight: .semibold)
    static let valuePillFont: Font = .system(size: 10, weight: .semibold)
    static let actionButtonFont: Font = .system(size: 12, weight: .semibold)
    static let whitelistRowTitleFont: Font = .system(size: 13, weight: .semibold)
    static let whitelistRowPathFont: Font = .system(size: 10, weight: .medium)
    static let whitelistIconFont: Font = .system(size: 16, weight: .semibold)
    static let whitelistEmptyIconFont: Font = .system(size: 28, weight: .semibold)
    static let whitelistEmptyTitleFont: Font = .system(size: 14, weight: .semibold)
    static let whitelistEmptySubtitleFont: Font = .system(size: 10, weight: .medium)
    static let panelBackground = LinearGradient(
        colors: [
            Color(red: 0.23, green: 0.13, blue: 0.17),
            Color(red: 0.09, green: 0.10, blue: 0.13)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let chromeFill = LinearGradient(
        colors: [
            Color(red: 0.18, green: 0.11, blue: 0.16).opacity(0.96),
            Color(red: 0.11, green: 0.11, blue: 0.15).opacity(0.98)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cardFill = Color(red: 0.16, green: 0.13, blue: 0.18).opacity(0.92)
    static let cardOverlay = Color.white.opacity(0.06)
    static let controlFill = Color.white.opacity(0.05)
    static let selectedControlFill = Color(red: 0.23, green: 0.32, blue: 0.51)
    static let accent = Color(red: 0.44, green: 0.63, blue: 0.95)
    static let accentSoft = Color(red: 0.27, green: 0.39, blue: 0.60)
    static let textPrimary = Color(red: 0.96, green: 0.94, blue: 0.98)
    static let textSecondary = Color(red: 0.71, green: 0.69, blue: 0.76)
    static let textMuted = Color(red: 0.55, green: 0.53, blue: 0.61)
    static let divider = Color.white.opacity(0.08)
    static let shadow = Color.black.opacity(0.34)
    static let primaryButton = LinearGradient(
        colors: [
            Color(red: 0.39, green: 0.59, blue: 0.95),
            Color(red: 0.31, green: 0.47, blue: 0.86)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let secondaryButton = Color.white.opacity(0.06)
}

final class MenuPanelModel: ObservableObject {
    @Published var selectedTab: MenuPanelTab = .general
    @Published var startAtLogin: Bool
    @Published var doubleTapIntervalDraft: Double
    @Published var alertCloseTimeDraft: Double
    @Published var whitelistSearchText: String = "" {
        didSet {
            refreshFilteredWhitelistItems()
        }
    }
    @Published var selectedWhitelistItem: String?
    @Published private(set) var whitelistItems: [String]
    @Published private(set) var filteredWhitelistItems: [String]

    private let config: QuitGuardConfig
    private let blackList: BlackList
    private let setAutoLaunch: (Bool) -> Void
    private let selectApp: (@escaping (URL?) -> Void) -> Void
    private let quitAction: () -> Void
    private var cancellables: Set<AnyCancellable> = []

    init(
        config: QuitGuardConfig = .shared,
        blackList: BlackList = .this,
        isAutoLaunchEnabled: @escaping () -> Bool = { AutoLaunch.isEnabledAutoLaunch },
        setAutoLaunch: @escaping (Bool) -> Void = {
            $0 ? AutoLaunch.enableAutoLaunch() : AutoLaunch.disableAutoLaunch()
        },
        selectApp: @escaping (@escaping (URL?) -> Void) -> Void = { completion in
            FileSelector.openFile(selectApp: completion)
        },
        quitAction: @escaping () -> Void = { NSApplication.shared.terminate(nil) }
    ) {
        self.config = config
        self.blackList = blackList
        self.setAutoLaunch = setAutoLaunch
        self.selectApp = selectApp
        self.quitAction = quitAction
        self.startAtLogin = isAutoLaunchEnabled()
        self.doubleTapIntervalDraft = config.doubleTapInterval
        self.alertCloseTimeDraft = config.alertWindowCloseTime
        self.whitelistItems = blackList.records
        self.filteredWhitelistItems = blackList.records
        bindWhitelist()
    }

    var hasPendingChanges: Bool {
        config.doubleTapInterval != doubleTapIntervalDraft ||
        config.alertWindowCloseTime != alertCloseTimeDraft
    }

    var summaryText: String {
        let suffix = whitelistItems.isEmpty ? "暂未设置跳过应用" : "已放行 \(whitelistItems.count) 个应用"
        return hasPendingChanges ? "有未应用更改 · \(suffix)" : "双击 Cmd+Q 才会退出 · \(suffix)"
    }

    var whitelistSubtitleText: String {
        if whitelistItems.isEmpty {
            return "放行后不会触发二次确认，适合你明确不想拦截的应用。"
        }
        if hasActiveWhitelistSearch {
            return "共 \(whitelistItems.count) 个应用，当前匹配 \(filteredWhitelistItems.count) 个。"
        }
        return "当前已放行 \(whitelistItems.count) 个应用，点击条目后可直接移除。"
    }

    func toggleLaunchAtLogin(_ isEnabled: Bool) {
        startAtLogin = isEnabled
        setAutoLaunch(isEnabled)
    }

    func applySettings() {
        config.doubleTapInterval = doubleTapIntervalDraft
        config.alertWindowCloseTime = alertCloseTimeDraft
    }

    func selectWhitelistItem(_ item: String?) {
        selectedWhitelistItem = item
    }

    func addWhitelistApp() {
        selectApp { [weak self] url in
            self?.appendWhitelist(url)
        }
    }

    func removeSelectedWhitelistItem() {
        blackList.remove(data: selectedWhitelistItem)
    }

    func quitApp() {
        quitAction()
    }
}

private extension MenuPanelModel {
    var hasActiveWhitelistSearch: Bool {
        !normalizedWhitelistSearchText.isEmpty
    }

    var normalizedWhitelistSearchText: String {
        whitelistSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func bindWhitelist() {
        blackList.$records
            .receive(on: RunLoop.main)
            .sink { [weak self] records in
                self?.syncWhitelist(records)
            }
            .store(in: &cancellables)
    }

    func syncWhitelist(_ records: [String]) {
        whitelistItems = records
        refreshFilteredWhitelistItems()
    }

    func appendWhitelist(_ url: URL?) {
        guard let url else { return }
        blackList.append(data: url.path)
    }

    func refreshFilteredWhitelistItems() {
        filteredWhitelistItems = makeFilteredWhitelistItems()
        syncSelectedWhitelistItem()
    }

    func makeFilteredWhitelistItems() -> [String] {
        let query = normalizedWhitelistSearchText
        guard !query.isEmpty else { return whitelistItems }
        return whitelistItems.filter { matchesWhitelistSearch(in: $0, query: query) }
    }

    func matchesWhitelistSearch(in item: String, query: String) -> Bool {
        let appName = URL(fileURLWithPath: item)
            .deletingPathExtension()
            .lastPathComponent
        return appName.localizedCaseInsensitiveContains(query) ||
            item.localizedCaseInsensitiveContains(query)
    }

    func syncSelectedWhitelistItem() {
        guard let selectedWhitelistItem else { return }
        guard filteredWhitelistItems.contains(selectedWhitelistItem) else {
            self.selectedWhitelistItem = nil
            return
        }
    }
}

struct MenuPanelScreen: View {
    @ObservedObject var model: MenuPanelModel

    let size: MenuPanelSize

    var body: some View {
        ZStack {
            MenuPanelStyle.panelBackground
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: MenuPanelStyle.cornerRadius, style: .continuous)
                .fill(MenuPanelStyle.chromeFill)
                .overlay(cardStroke)
                .shadow(color: MenuPanelStyle.shadow, radius: 24, x: 0, y: 18)
                .overlay(alignment: .topLeading) {
                    content
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .topLeading
                        )
                        .padding(size.outerPadding)
                }
                .padding(MenuPanelStyle.chromePadding)
        }
        .frame(width: size.width, height: size.height)
        .preferredColorScheme(.dark)
    }
}

private extension MenuPanelScreen {
    var cardStroke: some View {
        RoundedRectangle(cornerRadius: MenuPanelStyle.cornerRadius, style: .continuous)
            .stroke(MenuPanelStyle.cardOverlay, lineWidth: 1)
    }

    var content: some View {
        VStack(alignment: .leading, spacing: MenuPanelStyle.sectionSpacing) {
            MenuPanelHeader(
                title: "CQ",
                subtitle: model.summaryText
            )
            MenuPanelSegmentedControl(selectedTab: $model.selectedTab)
            MenuPanelContentViewport {
                activeContent
            }
            MenuActionBar(model: model)
        }
    }

    @ViewBuilder
    var activeContent: some View {
        switch model.selectedTab {
        case .general:
            GeneralSettingsSection(model: model)
        case .whitelist:
            WhitelistSection(model: model)
        }
    }
}

struct MenuPanelContentViewport<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MenuPanelHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPanelStyle.headerSpacing) {
            HStack(alignment: .center, spacing: MenuPanelStyle.headerTitleRowSpacing) {
                appIcon
                Text(title)
                    .font(MenuPanelStyle.headerTitleFont)
                    .foregroundStyle(MenuPanelStyle.textPrimary)
                    .layoutPriority(1)
            }
            Text(subtitle)
                .font(MenuPanelStyle.headerSubtitleFont)
                .foregroundStyle(MenuPanelStyle.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension MenuPanelHeader {
    var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .padding(8)
        }
        .frame(width: MenuPanelStyle.headerIconSize, height: MenuPanelStyle.headerIconSize)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MenuPanelStyle.cardOverlay, lineWidth: 1)
        )
    }
}

struct MenuPanelSegmentedControl: View {
    @Binding var selectedTab: MenuPanelTab

    var body: some View {
        HStack(spacing: MenuPanelStyle.segmentedSpacing) {
            ForEach(MenuPanelTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(MenuPanelStyle.segmentedLabelFont)
                        .foregroundStyle(textColor(for: tab))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MenuPanelStyle.segmentedVerticalPadding)
                        .background(tabBackground(for: tab))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MenuPanelStyle.segmentedContainerPadding)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MenuPanelStyle.controlFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MenuPanelStyle.cardOverlay, lineWidth: 1)
        )
    }
}

private extension MenuPanelSegmentedControl {
    func textColor(for tab: MenuPanelTab) -> Color {
        selectedTab == tab ? MenuPanelStyle.textPrimary : MenuPanelStyle.textSecondary
    }

    @ViewBuilder
    func tabBackground(for tab: MenuPanelTab) -> some View {
        if selectedTab == tab {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MenuPanelStyle.selectedControlFill)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.clear)
        }
    }
}

struct MenuPanelCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPanelStyle.cardSpacing) {
            VStack(alignment: .leading, spacing: MenuPanelStyle.textStackSpacing) {
                Text(title)
                    .font(MenuPanelStyle.cardTitleFont)
                    .foregroundStyle(MenuPanelStyle.textPrimary)
                Text(subtitle)
                    .font(MenuPanelStyle.helperFont)
                    .foregroundStyle(MenuPanelStyle.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(MenuPanelStyle.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: MenuPanelStyle.cardCornerRadius, style: .continuous)
                .fill(MenuPanelStyle.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MenuPanelStyle.cardCornerRadius, style: .continuous)
                .stroke(MenuPanelStyle.cardOverlay, lineWidth: 1)
        )
    }
}

struct MenuActionBar: View {
    @ObservedObject var model: MenuPanelModel

    var body: some View {
        HStack(spacing: MenuPanelStyle.actionBarSpacing) {
            MenuInlineActionButton(
                title: "退出",
                systemImage: "power",
                kind: .secondary,
                isDisabled: false,
                action: model.quitApp
            )
            MenuInlineActionButton(
                title: "应用更改",
                systemImage: "checkmark.circle.fill",
                kind: .primary,
                isDisabled: !model.hasPendingChanges,
                action: model.applySettings
            )
        }
        .padding(.top, 2)
    }
}

enum MenuPanelActionKind {
    case primary
    case secondary
}

struct MenuInlineActionButton: View {
    let title: String
    let systemImage: String
    let kind: MenuPanelActionKind
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(MenuPanelStyle.actionButtonFont)
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, MenuPanelStyle.actionButtonVerticalPadding)
                .padding(.horizontal, MenuPanelStyle.actionButtonHorizontalPadding)
                .background(backgroundView)
                .overlay(borderView)
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.45 : 1)
        .disabled(isDisabled)
    }
}

private extension MenuInlineActionButton {
    var foregroundColor: Color {
        kind == .primary ? MenuPanelStyle.textPrimary : MenuPanelStyle.textSecondary
    }

    var backgroundView: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(kind == .primary ? AnyShapeStyle(MenuPanelStyle.primaryButton) : AnyShapeStyle(MenuPanelStyle.secondaryButton))
    }

    var borderView: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(MenuPanelStyle.cardOverlay, lineWidth: 1)
    }
}

#Preview {
    MenuShowView()
}
