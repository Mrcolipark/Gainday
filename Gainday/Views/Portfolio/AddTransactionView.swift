import SwiftUI
import SwiftData
import WidgetKit

/// 添加交易记录 - 统一设计语言
struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let portfolios: [Portfolio]
    var existingHolding: Holding? = nil

    @State private var selectedPortfolio: Portfolio?
    @State private var transactionType: TransactionType = .buy
    @State private var symbolText = ""
    @State private var holdingName = ""
    @State private var quantity = ""
    @State private var price = ""
    @State private var investmentAmount = ""
    @State private var fee = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var selectedMarket: Market = .JP
    @State private var showSymbolSearch = false
    @State private var isLoadingNAV = false

    /// 当前选中账户的账户类型
    private var currentAccountType: AccountType {
        selectedPortfolio?.accountTypeEnum ?? .general
    }

    /// 当前账户允许的市场
    private var allowedMarkets: [Market] {
        currentAccountType.allowedMarkets
    }

    /// 是否需要验证つみたて対象商品
    private var requiresTsumitateEligible: Bool {
        currentAccountType.requiresTsumitateEligible
    }

    /// 计算 NISA 额度
    private var nisaQuota: NISAOverallQuota {
        NISAQuotaCalculator.calculateOverall(holdings: portfolios.flatMap(\.holdings))
    }

    /// 当前交易金额
    private var currentTransactionAmount: Double {
        if isMutualFund && investmentMode == .fixedAmount {
            return Double(investmentAmount) ?? 0
        } else {
            let qty = Double(quantity) ?? 0
            let prc = Double(price) ?? 0
            let feeAmount = Double(fee) ?? 0
            return qty * prc + feeAmount
        }
    }

    /// NISA 额度验证警告（超额时阻止保存）
    private var nisaQuotaWarning: String? {
        guard currentAccountType.isNISA, transactionType == .buy else { return nil }

        let amount = currentTransactionAmount
        guard amount > 0 else { return nil }

        // 年度额度检查
        switch currentAccountType {
        case .nisa_tsumitate:
            if amount > nisaQuota.tsumitateAnnualRemaining {
                return "超出つみたて枠年度剩余额度".localized + " (\(formatManYen(nisaQuota.tsumitateAnnualRemaining)))"
            }
        case .nisa_growth:
            if amount > nisaQuota.growthAnnualRemaining {
                return "超出成長枠年度剩余额度".localized + " (\(formatManYen(nisaQuota.growthAnnualRemaining)))"
            }
        default:
            break
        }

        // 生涯额度检查（1800万円上限）
        if amount > nisaQuota.lifetimeRemaining {
            return "超出NISA生涯非課税枠".localized + " (\(formatManYen(nisaQuota.lifetimeRemaining)))"
        }

        // 成長枠生涯上限检查（1200万円）
        if currentAccountType == .nisa_growth {
            let growthLifetimeRemaining = max(0, nisaQuota.growthLifetimeLimit - nisaQuota.growthLifetimeUsed)
            if amount > growthLifetimeRemaining {
                return "超出成長枠生涯上限".localized + " (\(formatManYen(growthLifetimeRemaining)))"
            }
        }

        return nil
    }

    enum InvestmentMode: String, CaseIterable {
        case fixedAmount = "定额"
        case fixedQuantity = "定量"

        var displayName: String {
            rawValue.localized
        }
    }
    @State private var investmentMode: InvestmentMode = .fixedQuantity

    private var isMutualFund: Bool {
        selectedMarket == .JP_FUND
    }

    /// 是否针对已有标的添加交易（跳过标的选择）
    private var isExistingHoldingMode: Bool {
        existingHolding != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isExistingHoldingMode {
                        // 已有标的模式：显示标的信息（只读）
                        existingHoldingBanner
                    } else {
                        // 账户选择
                        accountSection

                        // 账户类型提示（仅显示，不可选择）
                        if currentAccountType.isNISA {
                            accountTypeInfoBanner
                        }
                    }

                    // 交易类型
                    transactionTypeSection

                    // 标的信息（仅新建模式）
                    if !isExistingHoldingMode {
                        symbolSection
                    }

                    // 交易详情
                    if isMutualFund {
                        mutualFundSection
                    } else {
                        stockTransactionSection
                    }

                    // 汇总预览
                    summarySection

                    // 验证提示
                    if let message = validationMessage {
                        validationBanner(message)
                    }

                    // NISA 额度警告
                    if let warning = nisaQuotaWarning {
                        nisaQuotaWarningBanner(warning)
                    }

                    Spacer(minLength: 100)
                }
                .padding(16)
            }
            .background(AppColors.background)
            .safeAreaInset(edge: .bottom) {
                saveButtonBar
            }
            .navigationTitle("添加交易".localized)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消".localized) { dismiss() }
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
            .sheet(isPresented: $showSymbolSearch) {
                SymbolSearchView(accountType: currentAccountType) { symbol, name, market in
                    symbolText = symbol
                    holdingName = name
                    selectedMarket = market
                    if market == .JP_FUND {
                        Task { await fetchCurrentNAV() }
                    }
                }
            }
            .onChange(of: selectedMarket) { _, newMarket in
                if newMarket == .JP_FUND {
                    investmentMode = .fixedAmount
                } else {
                    investmentMode = .fixedQuantity
                }
            }
            .onAppear {
                if let holding = existingHolding {
                    // 已有标的模式：预填充信息
                    symbolText = holding.symbol
                    holdingName = holding.name
                    selectedMarket = holding.marketEnum
                    selectedPortfolio = holding.portfolio
                } else {
                    if selectedPortfolio == nil {
                        selectedPortfolio = portfolios.first
                    }
                    // 根据账户类型设置默认市场
                    if let portfolio = selectedPortfolio {
                        let allowed = portfolio.accountTypeEnum.allowedMarkets
                        if !allowed.contains(selectedMarket) {
                            selectedMarket = allowed.first ?? .JP
                        }
                    }
                }
            }
            .onChange(of: selectedPortfolio) { _, newPortfolio in
                // 切换账户时更新默认市场
                if let portfolio = newPortfolio {
                    let allowed = portfolio.accountTypeEnum.allowedMarkets
                    if !allowed.contains(selectedMarket) {
                        selectedMarket = allowed.first ?? .JP
                        // 清空标的信息
                        symbolText = ""
                        holdingName = ""
                    }
                    // つみたて枠只能买入，重置交易类型
                    if portfolio.accountTypeEnum == .nisa_tsumitate {
                        transactionType = .buy
                    }
                }
            }
        }
    }

    // MARK: - 账户选择

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("选择账户".localized)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(portfolios) { portfolio in
                        Button {
                            selectedPortfolio = portfolio
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(portfolio.tagColor)
                                    .frame(width: 8, height: 8)
                                Text(portfolio.name)
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundStyle(selectedPortfolio?.id == portfolio.id ? .white : AppColors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selectedPortfolio?.id == portfolio.id ? AppColors.profit : AppColors.cardSurface)
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - 账户类型信息提示

    private var accountTypeInfoBanner: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: currentAccountType.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(currentAccountType.color)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(currentAccountType.color.opacity(0.15))
                )

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(currentAccountType.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 8) {
                    if currentAccountType == .nisa_tsumitate {
                        Text("剩余额度".localized + ": " + formatManYen(nisaQuota.tsumitateAnnualRemaining))
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary)

                        Text("·")
                            .foregroundStyle(AppColors.textTertiary)

                        Text("只能买入対象商品".localized)
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                    } else if currentAccountType == .nisa_growth {
                        Text("剩余额度".localized + ": " + formatManYen(nisaQuota.growthAnnualRemaining))
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(currentAccountType.color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(currentAccountType.color.opacity(0.3), lineWidth: 1)
        )
    }

    /// NISA 额度警告横幅
    private func nisaQuotaWarningBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.yellow)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.yellow.opacity(0.15))
        )
    }

    private func formatManYen(_ value: Double) -> String {
        let manYen = value / 10000
        if manYen >= 100 {
            return String(format: "¥%.0f万", manYen)
        } else if manYen >= 1 {
            return String(format: "¥%.1f万", manYen)
        } else {
            return String(format: "¥%.0f", value)
        }
    }

    // MARK: - 已有标的信息（只读）

    private var existingHoldingBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(symbolText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(holdingName)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if let portfolio = selectedPortfolio {
                HStack(spacing: 6) {
                    Circle()
                        .fill(portfolio.tagColor)
                        .frame(width: 8, height: 8)
                    Text(portfolio.name)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - 交易类型

    /// 当前账户允许的交易类型（つみたて枠只能买入）
    private var availableTransactionTypes: [TransactionType] {
        if currentAccountType == .nisa_tsumitate {
            return [.buy]
        }
        return TransactionType.allCases.map { $0 }
    }

    private var transactionTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("交易类型".localized)

            HStack(spacing: 0) {
                ForEach(availableTransactionTypes) { type in
                    Button {
                        transactionType = type
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 20))
                            Text(type.displayName)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(transactionType == type ? .white : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(transactionType == type ? typeColor(type) : Color.clear)
                        )
                    }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    private func typeColor(_ type: TransactionType) -> Color {
        switch type {
        case .buy: return AppColors.profit
        case .sell: return AppColors.loss
        case .dividend: return .blue
        }
    }

    // MARK: - 标的信息

    private var symbolSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("标的信息".localized)

            VStack(spacing: 16) {
                // 代码输入 - label 单独一行，input + 搜索按钮同行对齐
                VStack(alignment: .leading, spacing: 8) {
                    Text("代码".localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            TextField(
                                "",
                                text: $symbolText,
                                prompt: Text(isMutualFund ? "如 0331418A".localized : "如 7203.T".localized)
                                    .foregroundStyle(AppColors.textTertiary)
                            )
                            .font(.system(size: 16))
                            .foregroundStyle(AppColors.textPrimary)
                            #if os(iOS)
                            .keyboardType(.default)
                            .textInputAutocapitalization(.characters)
                            #endif
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppColors.elevatedSurface)
                        )

                        Button {
                            showSymbolSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(AppColors.profit)
                                )
                        }
                    }
                }

                // 名称输入
                FormField(
                    label: "名称".localized,
                    placeholder: "标的名称".localized,
                    text: $holdingName
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - 投信交易

    private var mutualFundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("投资详情".localized)

            VStack(spacing: 16) {
                // 投资方式选择
                HStack(spacing: 0) {
                    ForEach(InvestmentMode.allCases, id: \.self) { mode in
                        Button {
                            investmentMode = mode
                        } label: {
                            Text(mode.displayName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(investmentMode == mode ? .white : AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(investmentMode == mode ? AppColors.profit : Color.clear)
                                )
                        }
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.elevatedSurface)
                )

                if investmentMode == .fixedAmount {
                    // 定额模式
                    FormField(
                        label: "投资金额".localized,
                        placeholder: "10000",
                        text: $investmentAmount,
                        suffix: "円".localized,
                        keyboardType: .numberPad
                    )

                    HStack(spacing: 12) {
                        FormField(
                            label: "基准价格".localized,
                            placeholder: "0",
                            text: $price,
                            suffix: "円".localized,
                            keyboardType: .decimalPad
                        )

                        if !symbolText.isEmpty {
                            Button {
                                Task { await fetchCurrentNAV() }
                            } label: {
                                if isLoadingNAV {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16, weight: .medium))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppColors.profit)
                            )
                            .disabled(isLoadingNAV)
                        }
                    }
                } else {
                    // 定量模式
                    FormField(
                        label: "口数".localized,
                        placeholder: "0",
                        text: $quantity,
                        suffix: "口".localized,
                        keyboardType: .decimalPad
                    )

                    FormField(
                        label: "基准价格".localized,
                        placeholder: "0",
                        text: $price,
                        suffix: "円".localized,
                        keyboardType: .decimalPad
                    )
                }

                datePickerField

                FormField(
                    label: "备注".localized,
                    placeholder: "可选".localized,
                    text: $note
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - 股票交易

    private var stockTransactionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("交易详情".localized)

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    FormField(
                        label: "数量".localized,
                        placeholder: "0",
                        text: $quantity,
                        suffix: "股".localized,
                        keyboardType: .decimalPad
                    )

                    FormField(
                        label: "价格".localized,
                        placeholder: "0",
                        text: $price,
                        suffix: selectedMarket.currency,
                        keyboardType: .decimalPad
                    )
                }

                FormField(
                    label: "手续费".localized,
                    placeholder: "0",
                    text: $fee,
                    suffix: selectedMarket.currency,
                    keyboardType: .decimalPad
                )

                datePickerField

                FormField(
                    label: "备注".localized,
                    placeholder: "可选".localized,
                    text: $note
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - 汇总

    @ViewBuilder
    private var summarySection: some View {
        if shouldShowSummary {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("汇总".localized)

                VStack(spacing: 12) {
                    if isMutualFund && investmentMode == .fixedAmount {
                        if let amount = Double(investmentAmount), let nav = Double(price), nav > 0 {
                            let units = amount / nav
                            summaryRow("取得口数".localized, value: String(format: "%.4f \("口".localized)", units), highlight: true)
                            summaryRow("投资金额".localized, value: amount.currencyFormatted(code: "JPY"))
                        }
                    } else {
                        if let qty = Double(quantity), let prc = Double(price), qty > 0, prc > 0 {
                            let feeAmount = Double(fee) ?? 0
                            let total = qty * prc + feeAmount
                            summaryRow("数量".localized, value: "\(qty.formatted()) \(isMutualFund ? "口".localized : "股".localized)")
                            summaryRow("价格".localized, value: prc.currencyFormatted(code: selectedMarket.currency))
                            if feeAmount > 0 {
                                summaryRow("手续费".localized, value: feeAmount.currencyFormatted(code: selectedMarket.currency))
                            }
                            Divider()
                                .background(AppColors.dividerColor)
                            summaryRow("总金额".localized, value: total.currencyFormatted(code: selectedMarket.currency), highlight: true)
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
    }

    private var shouldShowSummary: Bool {
        if isMutualFund && investmentMode == .fixedAmount {
            return Double(investmentAmount) ?? 0 > 0 && Double(price) ?? 0 > 0
        } else {
            return Double(quantity) ?? 0 > 0 && Double(price) ?? 0 > 0
        }
    }

    private func summaryRow(_ title: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: highlight ? 18 : 15, weight: highlight ? .bold : .semibold, design: .monospaced))
                .foregroundStyle(highlight ? AppColors.profit : AppColors.textPrimary)
        }
    }

    // MARK: - 验证提示

    private func validationBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.orange.opacity(0.15))
        )
    }

    // MARK: - 保存按钮

    private var saveButtonBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.dividerColor)

            Button {
                saveTransaction()
            } label: {
                Text("保存交易".localized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isValid ? AppColors.profit : AppColors.textTertiary)
                    )
            }
            .disabled(!isValid)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppColors.cardSurface)
    }

    // MARK: - 辅助组件

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColors.textPrimary)
    }

    private var datePickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日期".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)

            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(AppColors.profit)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.elevatedSurface)
                )
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        guard selectedPortfolio != nil,
              !symbolText.isEmpty,
              !holdingName.isEmpty else { return false }

        if date > Date() { return false }

        // NISA 额度超限时阻止保存
        if nisaQuotaWarning != nil { return false }

        if isMutualFund && investmentMode == .fixedAmount {
            guard let amount = Double(investmentAmount), amount > 0,
                  let nav = Double(price), nav > 0 else { return false }
            guard amount >= 100 && amount <= 100_000_000 else { return false }
            return true
        } else {
            guard let qty = Double(quantity), qty > 0,
                  let prc = Double(price), prc > 0 else { return false }
            guard prc >= 0.0001 && prc <= 1_000_000_000 else { return false }
            return true
        }
    }

    private var validationMessage: String? {
        if date > Date() {
            return "交易日期不能是未来日期".localized
        }
        // つみたて対象商品验证
        if let error = tsumitateValidationError {
            return error
        }
        if isMutualFund && investmentMode == .fixedAmount {
            if let amount = Double(investmentAmount) {
                if amount < 100 { return "投资金额至少100円".localized }
                if amount > 100_000_000 { return "投资金额超出范围".localized }
            }
        } else {
            if let prc = Double(price) {
                if prc > 1_000_000_000 { return "价格超出合理范围".localized }
            }
        }
        return nil
    }

    // MARK: - Fetch NAV

    private func fetchCurrentNAV() async {
        guard !symbolText.isEmpty else { return }

        isLoadingNAV = true
        defer { isLoadingNAV = false }

        do {
            let fundQuote = try await JapanFundService.shared.fetchFundQuote(code: symbolText)
            await MainActor.run {
                price = String(format: "%.0f", fundQuote.nav)
                if holdingName.isEmpty {
                    holdingName = fundQuote.name
                }
            }
        } catch {
            // 静默失败
        }
    }

    // MARK: - Validation

    /// つみたて対象商品验证
    private var tsumitateValidationError: String? {
        guard requiresTsumitateEligible,
              isMutualFund,
              !symbolText.isEmpty else { return nil }

        if !TsumitateEligibleFundsService.knownEligibleFunds.contains(symbolText.uppercased()) {
            return "该商品不是つみたてNISA対象商品".localized
        }
        return nil
    }

    // MARK: - Market & Asset Type Detection

    /// 从 symbol 后缀自动推断市场，如果已通过搜索设置则使用 selectedMarket
    private func detectMarket(_ symbol: String) -> Market {
        let upper = symbol.uppercased()
        if upper.hasSuffix(".T") || upper.hasSuffix(".JP") {
            return .JP
        } else if upper.hasSuffix(".SS") || upper.hasSuffix(".SZ") {
            return .CN
        } else if upper.hasSuffix(".HK") {
            return .HK
        } else if upper.contains("-USD") || upper.contains("USDT") {
            return .CRYPTO
        }
        // 纯数字且长度符合日本投信代码特征
        let digits = upper.replacingOccurrences(of: "[^0-9A-Z]", with: "", options: .regularExpression)
        if digits.count >= 7 && selectedMarket == .JP_FUND {
            return .JP_FUND
        }
        return selectedMarket
    }

    /// 从市场自动推断资产类型
    private func inferAssetType(from market: Market) -> AssetType {
        switch market {
        case .JP_FUND: return .fund
        case .CRYPTO: return .crypto
        case .COMMODITY: return .metal
        default: return .stock
        }
    }

    // MARK: - Save

    private func saveTransaction() {
        guard let portfolio = selectedPortfolio else { return }

        // 验证つみたて対象商品
        if let error = tsumitateValidationError {
            // 显示错误（通过 validationMessage）
            return
        }

        let finalQuantity: Double
        let finalPrice: Double
        let feeAmount = Double(fee) ?? 0

        if isMutualFund && investmentMode == .fixedAmount {
            guard let amount = Double(investmentAmount),
                  let nav = Double(price), nav > 0 else { return }
            finalQuantity = amount / nav
            finalPrice = nav
        } else {
            guard let qty = Double(quantity),
                  let prc = Double(price) else { return }
            finalQuantity = qty
            finalPrice = prc
        }

        // 手动输入时通过 symbol 后缀自动推断市场
        let finalMarket = detectMarket(symbolText)
        let finalAssetType = inferAssetType(from: finalMarket)

        let holding: Holding
        // 查找是否已有该标的（同一 portfolio 内）
        if let existing = portfolio.holdings.first(where: { $0.symbol == symbolText }) {
            holding = existing
        } else {
            // 创建新持仓 - accountType 从 portfolio 继承
            holding = Holding(
                symbol: symbolText,
                name: holdingName,
                assetType: finalAssetType.rawValue,
                market: finalMarket.rawValue,
                accountType: portfolio.accountType  // 使用 portfolio 的账户类型
            )
            holding.portfolio = portfolio
            portfolio.holdings.append(holding)
        }

        let transaction = Transaction(
            type: transactionType.rawValue,
            date: date,
            quantity: finalQuantity,
            price: finalPrice,
            fee: feeAmount,
            currency: finalMarket.currency,
            note: note
        )
        transaction.holding = holding
        holding.transactions.append(transaction)

        modelContext.insert(transaction)

        // 通知日历视图刷新
        NotificationCenter.default.post(name: .portfolioDataDidChange, object: nil)

        // 通知 Widget 刷新
        WidgetCenter.shared.reloadAllTimelines()

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        dismiss()
    }
}

// MARK: - 表单输入组件

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var suffix: String? = nil
    var keyboardType: UIKeyboardType = .default
    var capitalization: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 8) {
                TextField(
                    "",
                    text: $text,
                    prompt: Text(placeholder)
                        .foregroundStyle(AppColors.textTertiary)
                )
                .font(.system(size: 16))
                .foregroundStyle(AppColors.textPrimary)
                #if os(iOS)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(capitalization ? .characters : .never)
                #endif

                if let suffix = suffix {
                    Text(suffix)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.elevatedSurface)
            )
        }
    }
}

#Preview {
    AddTransactionView(portfolios: [])
        .modelContainer(for: Portfolio.self, inMemory: true)
        .preferredColorScheme(.dark)
}
