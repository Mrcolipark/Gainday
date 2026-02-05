import SwiftUI
import SwiftData
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]

    @AppStorage("baseCurrency") private var baseCurrency = "JPY"
    @AppStorage("iCloudSync") private var iCloudSync = true
    @AppStorage("appearance") private var appearance = "system"

    @State private var showAccountManage = false
    @State private var showAddAccount = false
    @State private var showExportSheet = false
    @State private var portfolioToDelete: Portfolio?
    @State private var showDeleteConfirmation = false
    @State private var showImportPicker = false
    @State private var importResult: CSVImportService.ImportResult?
    @State private var showImportResult = false

    var body: some View {
        NavigationStack {
            List {
                // Currency
                Section {
                    HStack(spacing: 10) {
                        settingsIcon("yensign.circle.fill", color: .green)
                        Picker("基准货币", selection: $baseCurrency) {
                            ForEach(BaseCurrency.allCases) { currency in
                                Text(currency.displayName).tag(currency.rawValue)
                            }
                        }
                    }
                } header: {
                    Label("基准货币", systemImage: "dollarsign.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }

                // Account Management
                Section {
                    ForEach(portfolios) { portfolio in
                        NavigationLink {
                            AccountManageView(portfolio: portfolio)
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [portfolio.tagColor, portfolio.tagColor.opacity(0.6)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 32, height: 32)
                                    Image(systemName: portfolio.accountTypeEnum.iconName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(portfolio.name)
                                        .font(.subheadline.weight(.medium))
                                    HStack(spacing: 4) {
                                        Text(portfolio.accountTypeEnum.displayName)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("·")
                                            .foregroundStyle(.secondary.opacity(0.5))
                                        Text(portfolio.baseCurrencyEnum.rawValue)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            portfolioToDelete = portfolios[index]
                            showDeleteConfirmation = true
                        }
                    }
                    .onMove(perform: movePortfolios)

                    Button {
                        showAddAccount = true
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                            Text("添加账户")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Label("账户管理", systemImage: "building.columns")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }

                // Sync
                Section {
                    HStack(spacing: 10) {
                        settingsIcon("icloud.fill", color: .cyan)
                        Toggle("iCloud 同步", isOn: $iCloudSync)
                    }
                } header: {
                    Label("数据同步", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                }

                // Appearance
                Section {
                    HStack(spacing: 10) {
                        settingsIcon("paintpalette.fill", color: .purple)
                        Picker("主题", selection: $appearance) {
                            Text("跟随系统").tag("system")
                            Text("始终浅色").tag("light")
                            Text("始终深色").tag("dark")
                        }
                    }
                } header: {
                    Label("外观", systemImage: "moon.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                }

                // Data
                Section {
                    Button {
                        exportCSV()
                    } label: {
                        HStack(spacing: 10) {
                            settingsIcon("square.and.arrow.up.fill", color: .orange)
                            Text("导出数据 (CSV)")
                                .foregroundStyle(.primary)
                        }
                    }

                    Button {
                        showImportPicker = true
                    } label: {
                        HStack(spacing: 10) {
                            settingsIcon("square.and.arrow.down.fill", color: .teal)
                            Text("导入数据 (CSV)")
                                .foregroundStyle(.primary)
                        }
                    }
                } header: {
                    Label("数据管理", systemImage: "externaldrive")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                // About
                Section {
                    HStack(spacing: 10) {
                        settingsIcon("info.circle.fill", color: .indigo)
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        settingsIcon("sparkles", color: .pink)
                        Text("App 名称")
                        Spacer()
                        Text("GainDay 盈历")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com")!) {
                        HStack(spacing: 10) {
                            settingsIcon("envelope.fill", color: .blue)
                            Text("反馈与建议")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("关于", systemImage: "heart")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.pink)
                }

                // Debug section (remove in production)
                #if DEBUG
                DebugDataSection()
                #endif
            }
            .navigationTitle("设置")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
            #endif
            .sheet(isPresented: $showAddAccount) {
                AddAccountSheet()
            }
            .alert("确认删除", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {
                    portfolioToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let portfolio = portfolioToDelete {
                        modelContext.delete(portfolio)
                        portfolioToDelete = nil
                        ErrorPresenter.shared.showSuccess("账户已删除")
                    }
                }
            } message: {
                if let portfolio = portfolioToDelete {
                    Text("确定要删除「\(portfolio.name)」吗？\n\n该账户下的所有持仓和交易记录都将被永久删除，此操作无法恢复。")
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
            .alert("导入完成", isPresented: $showImportResult) {
                Button("确定") {
                    importResult = nil
                }
            } message: {
                if let result = importResult {
                    let errorsText = result.errors.isEmpty ? "" : "\n\n⚠️ \(result.errors.count) 条记录导入失败"
                    Text("成功导入:\n• 账户: \(result.portfoliosCreated) 个\n• 持仓: \(result.holdingsCreated) 个\n• 交易: \(result.transactionsCreated) 笔\(errorsText)")
                }
            }
        }
    }

    // MARK: - Settings Icon

    private func settingsIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
            Image(systemName: name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    // deletePortfolios 已移至 alert 中处理，带确认对话框

    private func movePortfolios(from source: IndexSet, to destination: Int) {
        var sorted = portfolios.sorted { $0.sortOrder < $1.sortOrder }
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, portfolio) in sorted.enumerated() {
            portfolio.sortOrder = index
        }
    }

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

// MARK: - Add Account Sheet

struct AddAccountSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var accountType: AccountType = .normal
    @State private var baseCurrency: BaseCurrency = .JPY
    @State private var colorTag = "blue"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("账户名称 (如: 楽天証券)", text: $name)

                    Picker("账户类型", selection: $accountType) {
                        ForEach(AccountType.allCases) { type in
                            Label(type.displayName, systemImage: type.iconName).tag(type)
                        }
                    }

                    Picker("基准货币", selection: $baseCurrency) {
                        ForEach(BaseCurrency.allCases) { currency in
                            Text(currency.displayName).tag(currency)
                        }
                    }
                } header: {
                    Label("账户信息", systemImage: "building.columns")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(AppColors.accountTagKeys, id: \.self) { key in
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.tagColor(key), AppColors.tagColor(key).opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                    .shadow(color: AppColors.tagColor(key).opacity(colorTag == key ? 0.4 : 0), radius: 6, x: 0, y: 2)
                                if colorTag == key {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .scaleEffect(colorTag == key ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: colorTag)
                            .onTapGesture {
                                colorTag = key
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("标识颜色", systemImage: "paintpalette")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                }
            }
            .navigationTitle("添加账户")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveAccount()
                    }
                    .disabled(name.isEmpty)
                    .font(.body.weight(.semibold))
                }
            }
        }
    }

    private func saveAccount() {
        let portfolio = Portfolio(
            name: name,
            accountType: accountType.rawValue,
            baseCurrency: baseCurrency.rawValue,
            colorTag: colorTag
        )
        modelContext.insert(portfolio)
        dismiss()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Portfolio.self, inMemory: true)
}
