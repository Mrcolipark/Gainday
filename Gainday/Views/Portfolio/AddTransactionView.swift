import SwiftUI
import SwiftData

/// 添加交易记录 - 统一设计语言
struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let portfolios: [Portfolio]

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
    @State private var selectedAssetType: AssetType = .stock
    @State private var showSymbolSearch = false
    @State private var isLoadingNAV = false

    enum InvestmentMode: String, CaseIterable {
        case fixedAmount = "定额"
        case fixedQuantity = "定量"
    }
    @State private var investmentMode: InvestmentMode = .fixedQuantity

    private var isMutualFund: Bool {
        selectedMarket == .JP_FUND
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 账户选择
                    accountSection

                    // 交易类型
                    transactionTypeSection

                    // 标的信息
                    symbolSection

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

                    Spacer(minLength: 100)
                }
                .padding(16)
            }
            .background(AppColors.background)
            .safeAreaInset(edge: .bottom) {
                saveButtonBar
            }
            .navigationTitle("添加交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
            .sheet(isPresented: $showSymbolSearch) {
                SymbolSearchView { symbol, name, market in
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
                    selectedAssetType = .fund
                } else {
                    investmentMode = .fixedQuantity
                }
            }
            .onAppear {
                if selectedPortfolio == nil {
                    selectedPortfolio = portfolios.first
                }
            }
        }
    }

    // MARK: - 账户选择

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("选择账户")

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

    // MARK: - 交易类型

    private var transactionTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("交易类型")

            HStack(spacing: 0) {
                ForEach(TransactionType.allCases) { type in
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
            sectionTitle("标的信息")

            VStack(spacing: 16) {
                // 代码输入
                HStack(spacing: 12) {
                    FormField(
                        label: "代码",
                        placeholder: isMutualFund ? "如 0331418A" : "如 7203.T",
                        text: $symbolText,
                        keyboardType: .default,
                        capitalization: true
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

                // 名称输入
                FormField(
                    label: "名称",
                    placeholder: "标的名称",
                    text: $holdingName
                )

                // 市场选择
                VStack(alignment: .leading, spacing: 8) {
                    Text("市场")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Market.allCases) { market in
                                Button {
                                    selectedMarket = market
                                } label: {
                                    Text("\(market.flag) \(market.displayName)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(selectedMarket == market ? .white : AppColors.textSecondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(selectedMarket == market ? AppColors.profit : AppColors.elevatedSurface)
                                        )
                                }
                            }
                        }
                    }
                }

                // 资产类型（非投信）
                if !isMutualFund {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("资产类型")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)

                        HStack(spacing: 8) {
                            ForEach(AssetType.allCases) { type in
                                Button {
                                    selectedAssetType = type
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: type.iconName)
                                            .font(.system(size: 14))
                                        Text(type.displayName)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(selectedAssetType == type ? .white : AppColors.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(selectedAssetType == type ? AppColors.profit : AppColors.elevatedSurface)
                                    )
                                }
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

    // MARK: - 投信交易

    private var mutualFundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("投资详情")

            VStack(spacing: 16) {
                // 投资方式选择
                HStack(spacing: 0) {
                    ForEach(InvestmentMode.allCases, id: \.self) { mode in
                        Button {
                            investmentMode = mode
                        } label: {
                            Text(mode.rawValue)
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
                        label: "投资金额",
                        placeholder: "10000",
                        text: $investmentAmount,
                        suffix: "円",
                        keyboardType: .numberPad
                    )

                    HStack(spacing: 12) {
                        FormField(
                            label: "基准价格",
                            placeholder: "0",
                            text: $price,
                            suffix: "円",
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
                        label: "口数",
                        placeholder: "0",
                        text: $quantity,
                        suffix: "口",
                        keyboardType: .decimalPad
                    )

                    FormField(
                        label: "基准价格",
                        placeholder: "0",
                        text: $price,
                        suffix: "円",
                        keyboardType: .decimalPad
                    )
                }

                datePickerField

                FormField(
                    label: "备注",
                    placeholder: "可选",
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
            sectionTitle("交易详情")

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    FormField(
                        label: "数量",
                        placeholder: "0",
                        text: $quantity,
                        suffix: "股",
                        keyboardType: .decimalPad
                    )

                    FormField(
                        label: "价格",
                        placeholder: "0",
                        text: $price,
                        suffix: selectedMarket.currency,
                        keyboardType: .decimalPad
                    )
                }

                FormField(
                    label: "手续费",
                    placeholder: "0",
                    text: $fee,
                    suffix: selectedMarket.currency,
                    keyboardType: .decimalPad
                )

                datePickerField

                FormField(
                    label: "备注",
                    placeholder: "可选",
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
                sectionTitle("汇总")

                VStack(spacing: 12) {
                    if isMutualFund && investmentMode == .fixedAmount {
                        if let amount = Double(investmentAmount), let nav = Double(price), nav > 0 {
                            let units = amount / nav
                            summaryRow("取得口数", value: String(format: "%.4f 口", units), highlight: true)
                            summaryRow("投资金额", value: amount.currencyFormatted(code: "JPY"))
                        }
                    } else {
                        if let qty = Double(quantity), let prc = Double(price), qty > 0, prc > 0 {
                            let feeAmount = Double(fee) ?? 0
                            let total = qty * prc + feeAmount
                            summaryRow("数量", value: "\(qty.formatted()) \(isMutualFund ? "口" : "股")")
                            summaryRow("价格", value: prc.currencyFormatted(code: selectedMarket.currency))
                            if feeAmount > 0 {
                                summaryRow("手续费", value: feeAmount.currencyFormatted(code: selectedMarket.currency))
                            }
                            Divider()
                                .background(AppColors.dividerColor)
                            summaryRow("总金额", value: total.currencyFormatted(code: selectedMarket.currency), highlight: true)
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
                Text("保存交易")
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
            Text("日期")
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
            return "交易日期不能是未来日期"
        }
        if isMutualFund && investmentMode == .fixedAmount {
            if let amount = Double(investmentAmount) {
                if amount < 100 { return "投资金额至少100円" }
                if amount > 100_000_000 { return "投资金额超出范围" }
            }
        } else {
            if let prc = Double(price) {
                if prc > 1_000_000_000 { return "价格超出合理范围" }
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

    // MARK: - Save

    private func saveTransaction() {
        guard let portfolio = selectedPortfolio else { return }

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

        let holding: Holding
        if let existing = portfolio.holdings.first(where: { $0.symbol == symbolText }) {
            holding = existing
        } else {
            holding = Holding(
                symbol: symbolText,
                name: holdingName,
                assetType: isMutualFund ? AssetType.fund.rawValue : selectedAssetType.rawValue,
                market: selectedMarket.rawValue
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
            currency: selectedMarket.currency,
            note: note
        )
        transaction.holding = holding
        holding.transactions.append(transaction)

        modelContext.insert(transaction)

        // 通知日历视图刷新
        NotificationCenter.default.post(name: .portfolioDataDidChange, object: nil)

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        dismiss()
    }
}

// MARK: - 表单输入组件

private struct FormField: View {
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
