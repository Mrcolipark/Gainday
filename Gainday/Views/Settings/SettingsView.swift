import SwiftUI
import SwiftData
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

/// 设置页面 - 统一设计语言（精简配色）
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]

    @AppStorage("baseCurrency") private var baseCurrency = "JPY"
    @AppStorage("iCloudSync") private var iCloudSync = true

    // 使用 AppearanceManager 管理主题
    @State private var appearanceManager = AppearanceManager.shared
    // 使用 LanguageManager 管理语言
    @State private var languageManager = LanguageManager.shared

    @State private var showAddAccount = false
    @State private var portfolioToDelete: Portfolio?
    @State private var showDeleteConfirmation = false
    @State private var showImportPicker = false
    @State private var importResult: CSVImportService.ImportResult?
    @State private var showImportResult = false

    // 主题色 - 统一使用绿色
    private let accentColor = AppColors.profit

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 基准货币
                    currencySection

                    // 账户管理
                    accountsSection

                    // 数据同步
                    syncSection

                    // 外观设置
                    appearanceSection

                    // 数据管理
                    dataSection

                    // 关于
                    aboutSection

                    // Debug
                    #if DEBUG
                    debugSection
                    #endif

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
            .background(AppColors.background)
            .navigationTitle("设置".localized)
            #if os(iOS)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成".localized) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor)
                }
            }
            #endif
            .sheet(isPresented: $showAddAccount) {
                AddAccountSheet()
            }
            .alert("确认删除".localized, isPresented: $showDeleteConfirmation) {
                Button("取消".localized, role: .cancel) {
                    portfolioToDelete = nil
                }
                Button("删除".localized, role: .destructive) {
                    if let portfolio = portfolioToDelete {
                        modelContext.delete(portfolio)
                        portfolioToDelete = nil
                        ErrorPresenter.shared.showSuccess("账户已删除".localized)
                    }
                }
            } message: {
                if let portfolio = portfolioToDelete {
                    Text("\("确定要删除吗".localized)\n「\(portfolio.name)」\n\n\("该账户下的所有持仓和交易记录都将被永久删除，此操作无法恢复。".localized)")
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        do {
                            importResult = try CSVImportService.importCSV(from: url, modelContext: modelContext)
                            showImportResult = true
                        } catch {
                            ErrorPresenter.shared.showError(error)
                        }
                    }
                case .failure(let error):
                    ErrorPresenter.shared.showError(error)
                }
            }
            .alert("导入完成".localized, isPresented: $showImportResult) {
                Button("确定".localized) {
                    importResult = nil
                }
            } message: {
                if let result = importResult {
                    let errorsText = result.errors.isEmpty ? "" : "\n\n⚠️ \(result.errors.count) \("条记录导入失败".localized)"
                    Text("\("成功导入".localized):\n• \("账户".localized): \(result.portfoliosCreated) \("个".localized)\n• \("持仓".localized): \(result.holdingsCreated) \("个".localized)\n• 交易: \(result.transactionsCreated) \("笔".localized)\(errorsText)")
                }
            }
        }
    }

    // MARK: - 基准货币

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("基准货币".localized, icon: "yensign.circle.fill")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    settingsIcon("yensign.circle.fill")

                    Text("基准货币".localized)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Picker("", selection: $baseCurrency) {
                        ForEach(BaseCurrency.allCases) { currency in
                            Text(currency.displayName).tag(currency.rawValue)
                        }
                    }
                    .labelsHidden()
                    .tint(AppColors.textSecondary)
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - 账户管理

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("账户管理".localized, icon: "building.columns.fill")

            VStack(spacing: 0) {
                ForEach(Array(portfolios.enumerated()), id: \.element.id) { index, portfolio in
                    NavigationLink {
                        AccountManageView(portfolio: portfolio)
                    } label: {
                        accountRow(portfolio)
                    }

                    if index < portfolios.count - 1 {
                        Divider()
                            .background(AppColors.dividerColor)
                            .padding(.leading, 60)
                    }
                }

                if !portfolios.isEmpty {
                    Divider()
                        .background(AppColors.dividerColor)
                }

                // 添加账户按钮
                Button {
                    showAddAccount = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(accentColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }

                        Text("添加账户".localized)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(accentColor)

                        Spacer()
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    private func accountRow(_ portfolio: Portfolio) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [portfolio.tagColor, portfolio.tagColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: portfolio.accountTypeEnum.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(portfolio.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 6) {
                    Text(portfolio.accountTypeEnum.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)

                    Text("·")
                        .foregroundStyle(AppColors.textTertiary.opacity(0.5))

                    Text(portfolio.baseCurrencyEnum.rawValue)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)

                    Text("·")
                        .foregroundStyle(AppColors.textTertiary.opacity(0.5))

                    Text("\(portfolio.holdings.count) \("持仓".localized)")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    // MARK: - 数据同步

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("数据同步".localized, icon: "arrow.triangle.2.circlepath")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    settingsIcon("icloud.fill")

                    Text("iCloud 同步".localized)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Toggle("", isOn: $iCloudSync)
                        .labelsHidden()
                        .tint(accentColor)
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - 外观设置

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("外观".localized, icon: "moon.circle.fill")

            VStack(spacing: 0) {
                // 主题
                HStack(spacing: 12) {
                    settingsIcon("circle.lefthalf.filled")

                    Text("主题".localized)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Picker("", selection: Binding(
                        get: { appearanceManager.appearance },
                        set: { appearanceManager.appearance = $0 }
                    )) {
                        Text("跟随系统".localized).tag("system")
                        Text("浅色".localized).tag("light")
                        Text("深色".localized).tag("dark")
                    }
                    .labelsHidden()
                    .tint(AppColors.textSecondary)
                }
                .padding(16)

                Divider()
                    .background(AppColors.dividerColor)
                    .padding(.leading, 60)

                // 语言
                HStack(spacing: 12) {
                    settingsIcon("globe")

                    Text("语言".localized)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Picker("", selection: Binding(
                        get: { languageManager.language },
                        set: { languageManager.language = $0 }
                    )) {
                        Text("跟随系统".localized).tag("system")
                        Text("简体中文").tag("zh-Hans")
                        Text("繁體中文").tag("zh-Hant")
                        Text("English").tag("en")
                        Text("日本語").tag("ja")
                    }
                    .labelsHidden()
                    .tint(AppColors.textSecondary)
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - 数据管理

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("数据管理".localized, icon: "externaldrive.fill")

            VStack(spacing: 0) {
                // 导出
                Button {
                    exportCSV()
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("square.and.arrow.up.fill")

                        Text("导出数据 (CSV)".localized)
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .background(AppColors.dividerColor)
                    .padding(.leading, 60)

                // 导入
                Button {
                    showImportPicker = true
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("square.and.arrow.down.fill")

                        Text("导入数据 (CSV)".localized)
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("关于".localized, icon: "info.circle.fill")

            VStack(spacing: 0) {
                // App 名称
                HStack(spacing: 12) {
                    settingsIcon("sparkles")

                    Text("App 名称".localized)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Text("GainDay 盈历".localized)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(16)

                Divider()
                    .background(AppColors.dividerColor)
                    .padding(.leading, 60)

                // 版本
                HStack(spacing: 12) {
                    settingsIcon("info.circle.fill")

                    Text("版本".localized)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Text("1.0.0")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(16)

                Divider()
                    .background(AppColors.dividerColor)
                    .padding(.leading, 60)

                // 反馈
                Link(destination: URL(string: "https://github.com/Mrcolipark/Gainday")!) {
                    HStack(spacing: 12) {
                        settingsIcon("bubble.left.and.bubble.right.fill")

                        Text("反馈与建议".localized)
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.textPrimary)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - Debug

    #if DEBUG
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("开发者选项".localized, icon: "hammer.fill")

            DebugDataSection()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
        }
    }
    #endif

    // MARK: - 辅助组件

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accentColor)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    /// 统一的设置图标 - 简洁绿色图标
    private func settingsIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(accentColor)
            .frame(width: 32, height: 32)
    }

    // MARK: - 数据操作

    private func exportCSV() {
        var csv = "Account,Symbol,Name,Type,Market,TransactionType,Date,Quantity,Price,Fee,Currency,Note\n"

        for portfolio in portfolios {
            for holding in portfolio.holdings {
                for tx in holding.transactions {
                    csv += "\"\(portfolio.name)\","
                    csv += "\"\(holding.symbol)\","
                    csv += "\"\(holding.name)\","
                    csv += "\"\(holding.assetType)\","
                    csv += "\"\(holding.market)\","
                    csv += "\"\(tx.type)\","
                    csv += "\"\(tx.date.shortDateString)\","
                    csv += "\(tx.quantity),"
                    csv += "\(tx.price),"
                    csv += "\(tx.fee),"
                    csv += "\"\(tx.currency)\","
                    csv += "\"\(tx.note)\"\n"
                }
            }
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("GainDay_Export.csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)

        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
    }

}

// MARK: - 添加账户 Sheet

struct AddAccountSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var accountType: AccountType = .normal
    @State private var baseCurrency: BaseCurrency = .JPY
    @State private var colorTag = "blue"

    private let accentColor = AppColors.profit

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 账户信息
                    accountInfoSection

                    // 标识颜色
                    colorSection

                    Spacer(minLength: 100)
                }
                .padding(16)
            }
            .background(AppColors.background)
            .safeAreaInset(edge: .bottom) {
                saveButtonBar
            }
            .navigationTitle("添加账户".localized)
            #if os(iOS)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消".localized) { dismiss() }
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
            #endif
        }
    }

    // MARK: - 账户信息

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("账户信息".localized)

            VStack(spacing: 16) {
                // 账户名称
                VStack(alignment: .leading, spacing: 8) {
                    Text("账户名称".localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    TextField(
                        "",
                        text: $name,
                        prompt: Text("如: 楽天証券、富途牛牛".localized)
                            .foregroundStyle(AppColors.textTertiary)
                    )
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppColors.elevatedSurface)
                    )
                }

                // 账户类型
                VStack(alignment: .leading, spacing: 8) {
                    Text("账户类型".localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(AccountType.allCases) { type in
                                Button {
                                    accountType = type
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: type.iconName)
                                            .font(.system(size: 14))
                                        Text(type.displayName)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(accountType == type ? .white : AppColors.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(accountType == type ? accentColor : AppColors.elevatedSurface)
                                    )
                                }
                            }
                        }
                    }
                }

                // 基准货币
                VStack(alignment: .leading, spacing: 8) {
                    Text("基准货币".localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    HStack(spacing: 10) {
                        ForEach(BaseCurrency.allCases) { currency in
                            Button {
                                baseCurrency = currency
                            } label: {
                                Text(currency.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(baseCurrency == currency ? .white : AppColors.textSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(baseCurrency == currency ? accentColor : AppColors.elevatedSurface)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - 标识颜色

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("标识颜色".localized)

            VStack(spacing: 16) {
                // 预览
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.tagColor(colorTag), AppColors.tagColor(colorTag).opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .shadow(color: AppColors.tagColor(colorTag).opacity(0.4), radius: 8, x: 0, y: 4)

                        Image(systemName: accountType.iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(name.isEmpty ? "账户名称".localized : name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("\(accountType.displayName) · \(baseCurrency.rawValue)")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.elevatedSurface)
                )

                // 颜色选择
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                    ForEach(AppColors.accountTagKeys, id: \.self) { key in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                colorTag = key
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.tagColor(key), AppColors.tagColor(key).opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                    .shadow(color: AppColors.tagColor(key).opacity(colorTag == key ? 0.5 : 0), radius: 8, x: 0, y: 4)

                                if colorTag == key {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .scaleEffect(colorTag == key ? 1.1 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - 保存按钮

    private var saveButtonBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.dividerColor)

            Button {
                saveAccount()
            } label: {
                Text("保存账户".localized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(name.isEmpty ? AppColors.textTertiary : accentColor)
                    )
            }
            .disabled(name.isEmpty)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppColors.cardSurface)
    }

    // MARK: - 辅助

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColors.textPrimary)
    }

    private func saveAccount() {
        let portfolio = Portfolio(
            name: name,
            accountType: accountType.rawValue,
            baseCurrency: baseCurrency.rawValue,
            colorTag: colorTag
        )
        modelContext.insert(portfolio)

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        dismiss()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Portfolio.self, inMemory: true)
        .preferredColorScheme(.dark)
}
