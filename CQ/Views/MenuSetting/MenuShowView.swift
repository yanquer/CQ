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
import ServiceManagement

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
    static let cornerRadius: CGFloat = 18
    static let cardCornerRadius: CGFloat = 16
    static let sectionSpacing: CGFloat = 12
    static let cardSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 14
    static let textStackSpacing: CGFloat = 4
    static let headerSpacing: CGFloat = 8
    static let headerTitleRowSpacing: CGFloat = 12
    static let headerIconSize: CGFloat = 32
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
    static let whitelistListPadding: CGFloat = 4
    static let whitelistButtonSpacing: CGFloat = 10
    static let whitelistRowSpacing: CGFloat = 12
    static let whitelistRowPadding: CGFloat = 10
    static let whitelistIconSize: CGFloat = 38
    static let whitelistSearchIconFont: Font = .system(size: 12, weight: .semibold)
    static let emptyStateSpacing: CGFloat = 10
    static let emptyStateHorizontalPadding: CGFloat = 18
    static let headerTitleFont: Font = .system(size: 18, weight: .bold, design: .rounded)
    static let headerSubtitleFont: Font = .system(size: 11)
    static let cardTitleFont: Font = .system(size: 14, weight: .semibold)
    static let helperFont: Font = .system(size: 11)
    static let settingTitleFont: Font = .system(size: 13, weight: .semibold)
    static let valuePillFont: Font = .system(size: 11, weight: .semibold)
    static let actionButtonFont: Font = .system(size: 12, weight: .semibold)
    static let whitelistRowTitleFont: Font = .system(size: 13, weight: .semibold)
    static let whitelistRowPathFont: Font = .system(size: 11)
    static let whitelistIconFont: Font = .system(size: 16, weight: .semibold)
    static let whitelistEmptyIconFont: Font = .system(size: 28, weight: .semibold)
    static let whitelistEmptyTitleFont: Font = .system(size: 14, weight: .semibold)
    static let whitelistEmptySubtitleFont: Font = .system(size: 11)
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
    static let statusHealthy = Color(red: 0.53, green: 0.83, blue: 0.67)
    static let statusWarning = Color(red: 0.98, green: 0.75, blue: 0.43)
    static let textPrimary = Color(red: 0.96, green: 0.94, blue: 0.98)
    static let textSecondary = Color(red: 0.71, green: 0.69, blue: 0.76)
    static let textMuted = Color(red: 0.72, green: 0.70, blue: 0.78)
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
    @Published var selectedTab: MenuPanelTab = .general {
        didSet {
            guard selectedTab != .whitelist else { return }
            dismissAppPicker()
        }
    }
    @Published private(set) var runtimeStatus: QuitGuardRuntimeStatus
    @Published private(set) var loginStatus: SMAppService.Status
    @Published private(set) var autoLaunchError: String?
    @Published var doubleTapIntervalDraft: Double
    @Published var alertCloseTimeDraft: Double
    @Published var whitelistSearchText: String = "" {
        didSet {
            refreshFilteredWhitelistItems()
        }
    }
    @Published var isShowingAppPicker: Bool = false
    @Published var isLoadingAppPicker: Bool = false
    @Published var appPickerSearchText: String = "" {
        didSet {
            refreshFilteredAppPickerItems()
        }
    }
    @Published var selectedWhitelistItem: String?
    @Published var selectedAppPickerItem: AppPickerItem?
    @Published private(set) var whitelistError: String?
    @Published private(set) var whitelistItems: [String]
    @Published private(set) var filteredWhitelistItems: [String]
    @Published private(set) var appPickerItems: [AppPickerItem]
    @Published private(set) var filteredAppPickerItems: [AppPickerItem]

    private let config: QuitGuardConfig
    private let blackList: BlackList
    private let appCatalog: InstalledAppCataloging
    private let systemAppPicker: SystemAppPicking
    private let appCatalogQueue: DispatchQueue
    private let autoLaunchStatus: () -> SMAppService.Status
    private let setAutoLaunch: (Bool) throws -> Void
    private let quitAction: () -> Void
    private let recheckProtectionAction: () -> Void
    private var cancellables: Set<AnyCancellable> = []
    private var appPickerRequestID: UUID?
    private var appPickerLoadWorkItem: DispatchWorkItem?
    private var shouldOpenFinderAfterDismissal: Bool = false

    /// 初始化面板配置、运行状态订阅及用户操作回调。
    init(
        config: QuitGuardConfig = .shared,
        blackList: BlackList = .this,
        appCatalog: InstalledAppCataloging = InstalledAppCatalog.shared,
        systemAppPicker: SystemAppPicking = SystemAppPicker(),
        appCatalogQueue: DispatchQueue = DispatchQueue(
            label: "com.yq.cq.app-catalog",
            qos: .userInitiated
        ),
        autoLaunchStatus: @escaping () -> SMAppService.Status = { AutoLaunch.status },
        setAutoLaunch: @escaping (Bool) throws -> Void = AutoLaunch.setEnabled,
        quitAction: @escaping () -> Void = { NSApplication.shared.terminate(nil) },
        runtimeStatus: QuitGuardRuntimeStatus = .tapDisabled,
        runtimeUpdates: AnyPublisher<QuitGuardRuntimeStatus, Never>? = nil,
        recheckProtectionAction: @escaping () -> Void = {}
    ) {
        self.config = config
        self.blackList = blackList
        self.appCatalog = appCatalog
        self.systemAppPicker = systemAppPicker
        self.appCatalogQueue = appCatalogQueue
        self.autoLaunchStatus = autoLaunchStatus
        self.setAutoLaunch = setAutoLaunch
        self.quitAction = quitAction
        self.runtimeStatus = runtimeStatus
        self.recheckProtectionAction = recheckProtectionAction
        self.loginStatus = autoLaunchStatus()
        self.doubleTapIntervalDraft = config.doubleTapInterval
        self.alertCloseTimeDraft = config.alertWindowCloseTime
        self.whitelistError = blackList.storageError
        self.whitelistItems = blackList.records
        self.filteredWhitelistItems = blackList.records
        self.appPickerItems = []
        self.filteredAppPickerItems = []
        bindWhitelist()
        runtimeUpdates?
            .receive(on: RunLoop.main)
            .sink { [weak self] status in self?.runtimeStatus = status }
            .store(in: &cancellables)
    }

    /// 开关表示已注册的启动请求；待批准时用独立提示明确尚未生效，并允许取消。
    var startAtLogin: Bool {
        loginStatus == .enabled || loginStatus == .requiresApproval
    }

    var autoLaunchMessage: String? {
        if let autoLaunchError { return autoLaunchError }
        switch loginStatus {
        case .requiresApproval:
            return "尚未生效，请在系统登录项设置中允许 CQ。"
        case .notFound:
            return "找不到应用，请将 CQ 移到“应用程序”后重试。"
        default:
            return nil
        }
    }

    var hasPendingChanges: Bool {
        config.doubleTapInterval != doubleTapIntervalDraft ||
        config.alertWindowCloseTime != alertCloseTimeDraft
    }

    /// 汇总次要设置状态，保护状态由页头单独展示。
    var settingsSummaryText: String {
        whitelistItems.isEmpty ? "暂未设置跳过应用" : "已放行 \(whitelistItems.count) 个应用"
    }

    var whitelistSubtitleText: String {
        if whitelistItems.isEmpty {
            return "这些应用可直接退出。添加和移除立即保存。"
        }
        if hasActiveWhitelistSearch {
            return "共 \(whitelistItems.count) 个应用，匹配 \(filteredWhitelistItems.count) 个。更改立即保存。"
        }
        return "已放行 \(whitelistItems.count) 个应用。添加和移除立即保存。"
    }

    var appPickerSubtitleText: String {
        if isLoadingAppPicker {
            return "正在整理已安装应用，请稍候。"
        }
        if hasActiveAppPickerSearch {
            return "共找到 \(appPickerItems.count) 个应用，当前匹配 \(filteredAppPickerItems.count) 个。"
        }
        return "选中应用后点击“添加”，也可浏览其他位置。"
    }

    var canConfirmAppPickerSelection: Bool {
        selectedAppPickerItem != nil && !isLoadingAppPicker
    }

    /// 重新读取权限并尝试恢复退出保护。
    func recheckProtection() {
        refreshAutoLaunchStatus()
        recheckProtectionAction()
    }

    /// 写入登录启动请求后重新读取系统状态，失败时保留真实开关状态并提示重试。
    func toggleLaunchAtLogin(_ isEnabled: Bool) {
        autoLaunchError = nil
        do {
            try setAutoLaunch(isEnabled)
        } catch {
            autoLaunchError = isEnabled ? "未能开启登录启动，请重试。" : "未能关闭登录启动，请重试。"
            AppLog.error("Login item update failed: requested=\(isEnabled), error=\(error)")
        }
        loginStatus = autoLaunchStatus()
    }

    /// 从系统设置返回时刷新登录启动状态及待批准提示。
    func refreshAutoLaunchStatus() {
        loginStatus = autoLaunchStatus()
        autoLaunchError = nil
    }

    func applySettings() {
        config.doubleTapInterval = doubleTapIntervalDraft
        config.alertWindowCloseTime = alertCloseTimeDraft
    }

    func selectWhitelistItem(_ item: String?) {
        selectedWhitelistItem = item
    }

    func addWhitelistApp() {
        presentAppPicker()
    }

    /// 移除所选应用并反馈保存结果，失败时保留原列表与选择以便重试。
    func removeSelectedWhitelistItem() {
        guard let selectedWhitelistItem else { return }
        let saved = blackList.remove(data: selectedWhitelistItem)
        whitelistError = saved ? nil : blackList.storageError
    }

    func selectAppPickerItem(_ item: AppPickerItem?) {
        selectedAppPickerItem = item
    }

    /// 保存成功后关闭选择层，失败时保留选择并展示可重试的错误。
    func confirmAppPickerSelection() {
        guard canConfirmAppPickerSelection else { return }
        guard appendWhitelist(selectedAppPickerItem?.path) else { return }
        dismissAppPicker()
    }

    func dismissAppPicker() {
        appPickerRequestID = nil
        appPickerLoadWorkItem?.cancel()
        appPickerLoadWorkItem = nil
        isShowingAppPicker = false
        isLoadingAppPicker = false
        appPickerSearchText = ""
        selectedAppPickerItem = nil
    }

    /// 先关闭原生选择窗口，再由关闭回调打开 Finder，避免两个模态窗口重叠。
    func addWhitelistAppFromFinder() {
        dismissAppPicker()
        shouldOpenFinderAfterDismissal = true
    }

    /// 在系统完成选择窗口的关闭动画后执行待处理的 Finder 选择，且只执行一次。
    func appPickerDidDismiss() {
        guard shouldOpenFinderAfterDismissal else { return }
        shouldOpenFinderAfterDismissal = false
        appendWhitelist(systemAppPicker.pickApp())
    }

    /// 面板释放时取消尚未启动的扫描，执行中的结果不会持有面板。
    deinit {
        appPickerLoadWorkItem?.cancel()
    }

    func quitApp() {
        quitAction()
    }
}

private extension MenuPanelModel {
    var hasActiveWhitelistSearch: Bool {
        !normalizedWhitelistSearchText.isEmpty
    }

    var hasActiveAppPickerSearch: Bool {
        !normalizedAppPickerSearchText.isEmpty
    }

    var normalizedWhitelistSearchText: String {
        normalizedSearchText(from: whitelistSearchText)
    }

    var normalizedAppPickerSearchText: String {
        normalizedSearchText(from: appPickerSearchText)
    }

    func bindWhitelist() {
        blackList.$storageError
            .receive(on: RunLoop.main)
            .sink { [weak self] error in self?.whitelistError = error }
            .store(in: &cancellables)
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
        appendWhitelist(url.path)
    }

    /// 保存选中的应用并返回结果，供选择层和 Finder 入口统一处理错误。
    @discardableResult
    func appendWhitelist(_ path: String?) -> Bool {
        guard let path else { return false }
        let saved = blackList.append(data: path)
        whitelistError = saved ? nil : blackList.storageError
        return saved
    }

    func refreshFilteredWhitelistItems() {
        filteredWhitelistItems = makeFilteredWhitelistItems()
        syncSelectedWhitelistItem()
    }

    func makeFilteredWhitelistItems() -> [String] {
        let query = normalizedWhitelistSearchText
        guard !query.isEmpty else { return whitelistItems }
        return whitelistItems.filter { matchesAppSearch(path: $0, query: query) }
    }

    /// 每次打开选择层时在后台刷新目录，避免新安装或卸载的应用被旧缓存掩盖。
    func presentAppPicker() {
        guard !isShowingAppPicker else { return }
        whitelistError = blackList.storageError
        isShowingAppPicker = true
        selectedAppPickerItem = nil
        appPickerSearchText = ""
        refreshAppPickerItemsIfNeeded(refresh: true)
    }

    func syncSelectedWhitelistItem() {
        guard let selectedWhitelistItem else { return }
        guard filteredWhitelistItems.contains(selectedWhitelistItem) else {
            self.selectedWhitelistItem = nil
            return
        }
    }

    /// 取消未启动的旧扫描，并用请求标识隔离已经开始的异步结果。
    func refreshAppPickerItemsIfNeeded(refresh: Bool = false) {
        guard refresh || appPickerItems.isEmpty else {
            refreshFilteredAppPickerItems()
            return
        }
        appPickerLoadWorkItem?.cancel()
        let requestID = UUID()
        appPickerRequestID = requestID
        isLoadingAppPicker = true
        let catalog = appCatalog
        let workItem = DispatchWorkItem { [weak self] in
            let items = catalog.loadApps(refresh: refresh)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isShowingAppPicker, self.appPickerRequestID == requestID else { return }
                self.appPickerLoadWorkItem = nil
                self.appPickerItems = items
                self.isLoadingAppPicker = false
                self.refreshFilteredAppPickerItems()
            }
        }
        appPickerLoadWorkItem = workItem
        appCatalogQueue.async(execute: workItem)
    }

    func refreshFilteredAppPickerItems() {
        filteredAppPickerItems = makeFilteredAppPickerItems()
        syncSelectedAppPickerItem()
    }

    func makeFilteredAppPickerItems() -> [AppPickerItem] {
        let query = normalizedAppPickerSearchText
        guard !query.isEmpty else { return appPickerItems }
        return appPickerItems.filter { matchesAppSearch(item: $0, query: query) }
    }

    func syncSelectedAppPickerItem() {
        guard let selectedAppPickerItem else { return }
        guard filteredAppPickerItems.contains(selectedAppPickerItem) else {
            self.selectedAppPickerItem = nil
            return
        }
    }

    func matchesAppSearch(item: AppPickerItem, query: String) -> Bool {
        matchesAppSearch(name: item.name, path: item.path, query: query)
    }

    func matchesAppSearch(path: String, query: String) -> Bool {
        let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        return matchesAppSearch(name: name, path: path, query: query)
    }

    func matchesAppSearch(name: String, path: String, query: String) -> Bool {
        name.localizedCaseInsensitiveContains(query) ||
            path.localizedCaseInsensitiveContains(query)
    }

    func normalizedSearchText(from text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MenuPanelScreen: View {
    @ObservedObject var model: MenuPanelModel
    @State private var ownsAppPicker: Bool = false

    let size: MenuPanelSize

    var body: some View {
        ZStack {
            MenuPanelStyle.panelBackground
                .ignoresSafeArea()
            content
                .padding(size.outerPadding)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: MenuPanelStyle.cornerRadius, style: .continuous))
        .preferredColorScheme(.dark)
        .sheet(
            isPresented: Binding(
                get: { ownsAppPicker && model.isShowingAppPicker },
                set: { if !$0 { model.dismissAppPicker() } }
            ),
            onDismiss: {
                ownsAppPicker = false
                model.appPickerDidDismiss()
            }
        ) {
            MenuAppPickerSheet(model: model)
                .padding(16)
                .frame(width: size.width)
                .background(MenuPanelStyle.panelBackground)
                .preferredColorScheme(.dark)
        }
    }
}

private extension MenuPanelScreen {
    var content: some View {
        VStack(alignment: .leading, spacing: MenuPanelStyle.sectionSpacing) {
            MenuPanelHeader(
                title: "CQ",
                status: model.runtimeStatus,
                subtitle: model.settingsSummaryText,
                recheckAction: model.recheckProtection
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
            WhitelistSection(model: model) {
                // 菜单与设置共用模型，但模态窗口只由点击添加的界面承载。
                ownsAppPicker = true
                model.addWhitelistApp()
            }
        }
    }
}

struct MenuPanelContentViewport<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical) {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MenuPanelHeader: View {
    let title: String
    let status: QuitGuardRuntimeStatus
    let subtitle: String
    let recheckAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPanelStyle.headerSpacing) {
            HStack(alignment: .center, spacing: MenuPanelStyle.headerTitleRowSpacing) {
                appIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MenuPanelStyle.headerTitleFont)
                        .foregroundStyle(MenuPanelStyle.textPrimary)
                    Text(subtitle)
                        .font(MenuPanelStyle.headerSubtitleFont)
                        .foregroundStyle(MenuPanelStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Label(
                        status.headlineText,
                        systemImage: status.isProtecting ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                    )
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(status.isProtecting ? MenuPanelStyle.statusHealthy : MenuPanelStyle.statusWarning)
                    Text(status.detailText)
                        .font(.system(size: 12))
                        .foregroundStyle(MenuPanelStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(status.summaryText)
                Button("重新检查", action: recheckAction)
                    .buttonStyle(.bordered)
                    .tint(status.isProtecting ? MenuPanelStyle.accent : MenuPanelStyle.statusWarning)
                    .help("检查权限并恢复退出保护")
            }
        }
    }
}

private extension MenuPanelHeader {
    var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                .padding(4)
        }
        .frame(width: MenuPanelStyle.headerIconSize, height: MenuPanelStyle.headerIconSize)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MenuPanelStyle.cardOverlay, lineWidth: 1)
        )
    }
}

struct MenuPanelSegmentedControl: View {
    @Binding var selectedTab: MenuPanelTab

    var body: some View {
        Picker("设置分类", selection: $selectedTab) {
            ForEach(MenuPanelTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.large)
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
        VStack(alignment: .leading, spacing: MenuPanelStyle.actionBarSpacing) {
            if model.selectedTab == .whitelist && model.hasPendingChanges {
                HStack {
                    Text("通用设置中有未保存的时间更改")
                        .font(MenuPanelStyle.helperFont)
                        .foregroundStyle(MenuPanelStyle.textSecondary)
                    Spacer()
                    Button("返回通用") {
                        model.selectedTab = .general
                    }
                    .buttonStyle(.bordered)
                }
            }
            HStack {
                Text("退出 CQ 后将停止保护")
                    .font(MenuPanelStyle.helperFont)
                    .foregroundStyle(MenuPanelStyle.textSecondary)
                Spacer()
                Button("退出 CQ", action: model.quitApp)
                    .buttonStyle(.borderless)
                    .foregroundStyle(MenuPanelStyle.textSecondary)
                    .help("关闭 CQ 并停止退出保护")
            }
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
