import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let portfolios: [Portfolio]

    @State private var selectedPortfolio: Portfolio?
    @State private var transactionType: TransactionType = .buy
    @State private var symbolText = ""
    @State private var holdingName = ""
    @State private var quantity = ""
    @State private var price = ""  // 股价 or 基準価額
    @State private var investmentAmount = ""  // 定額投資金額
    @State private var fee = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var selectedMarket: Market = .JP
    @State private var selectedAssetType: AssetType = .stock
    @State private var showSymbolSearch = false
    @State private var existingHolding: Holding?
    @State private var isLoadingNAV = false

    // 投資モード: 定額 (fixed amount) vs 定量 (fixed quantity)
    enum InvestmentMode: String, CaseIterable {
        case fixedAmount = "定額"   // 输入金额，自动计算口数
        case fixedQuantity = "定量" // 输入数量和价格
    }
    @State private var investmentMode: InvestmentMode = .fixedQuantity

    // 是否为投資信託（自动切换为定額模式）
    private var isMutualFund: Bool {
        selectedMarket == .JP_FUND
    }

    var body: some View {
        NavigationStack {
            Form {
                // Account selection
                Section {
                    Picker("选择账户", selection: $selectedPortfolio) {
                        Text("请选择").tag(nil as Portfolio?)
                        ForEach(portfolios) { portfolio in
                            HStack {
                                Circle()
                                    .fill(portfolio.tagColor)
                                    .frame(width: 8, height: 8)
                                Text(portfolio.name)
                            }
                            .tag(portfolio as Portfolio?)
                        }
                    }
                }

                // Transaction type
                Section("交易类型") {
                    Picker("类型", selection: $transactionType) {
                        ForEach(TransactionType.allCases) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Symbol
                Section("标的") {
                    HStack {
                        TextField(isMutualFund ? "基金代码 (如 0331418A)" : "代码 (如 7203.T)", text: $symbolText)
                            #if os(iOS)
                            .textInputAutocapitalization(.characters)
                            #endif
                        Button {
                            showSymbolSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                    }

                    TextField("名称", text: $holdingName)

                    Picker("市场", selection: $selectedMarket) {
                        ForEach(Market.allCases) { market in
                            Text("\(market.flag) \(market.displayName)").tag(market)
                        }
                    }

                    if !isMutualFund {
                        Picker("资产类型", selection: $selectedAssetType) {
                            ForEach(AssetType.allCases) { type in
                                Label(type.displayName, systemImage: type.iconName).tag(type)
                            }
                        }
                    }
                }

                // Investment mode (only show for mutual funds)
                if isMutualFund {
                    Section {
                        Picker("投資方式", selection: $investmentMode) {
                            ForEach(InvestmentMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Label("投資方式", systemImage: "yensign.circle")
                    } footer: {
                        Text(investmentMode == .fixedAmount
                             ? "定額: 输入投资金额，系统根据基準価額自动计算口数"
                             : "定量: 手动输入口数和基準価額")
                            .font(.caption2)
                    }
                }

                // Transaction details
                if isMutualFund && investmentMode == .fixedAmount {
                    // 定額投資模式 (投信专用)
                    Section("定額投資") {
                        HStack {
                            Text("投資金額")
                            Spacer()
                            TextField("10000", text: $investmentAmount)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                            Text("円")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("基準価額")
                            Spacer()
                            if isLoadingNAV {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            TextField("0", text: $price)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                            Text("円")
                                .foregroundStyle(.secondary)
                        }

                        // 自动获取基準価額按钮
                        if !symbolText.isEmpty {
                            Button {
                                Task { await fetchCurrentNAV() }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("获取最新基準価額")
                                }
                                .font(.subheadline)
                            }
                            .disabled(isLoadingNAV)
                        }

                        DatePicker("約定日", selection: $date, displayedComponents: .date)

                        TextField("备注 (可选)", text: $note)
                    }

                    // 计算结果
                    if let amount = Double(investmentAmount), let nav = Double(price), nav > 0 {
                        Section("計算結果") {
                            let units = amount / nav
                            HStack {
                                Text("取得口数")
                                Spacer()
                                Text(String(format: "%.4f", units))
                                    .font(.system(.body, design: .monospaced, weight: .semibold))
                                    .foregroundStyle(.blue)
                                Text("口")
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("投資金額")
                                Spacer()
                                Text(amount.currencyFormatted(code: "JPY"))
                                    .font(.headline.monospacedDigit())
                            }
                        }
                    }
                } else {
                    // 普通股票/定量模式
                    Section("交易详情") {
                        HStack {
                            Text(isMutualFund ? "口数" : "数量")
                            TextField("0", text: $quantity)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                        }

                        HStack {
                            Text(isMutualFund ? "基準価額" : "价格")
                            TextField("0", text: $price)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                        }

                        HStack {
                            Text("手续费")
                            TextField("0", text: $fee)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                        }

                        DatePicker("日期", selection: $date, displayedComponents: .date)

                        TextField("备注 (可选)", text: $note)
                    }

                    // Summary for regular mode
                    if let qty = Double(quantity), let prc = Double(price), qty > 0 && prc > 0 {
                        Section("汇总") {
                            let total = qty * prc + (Double(fee) ?? 0)
                            HStack {
                                Text("总金额")
                                Spacer()
                                Text(total.currencyFormatted(code: selectedMarket.currency))
                                    .font(.headline.monospacedDigit())
                            }
                        }
                    }
                }

                // Validation message
                if let message = validationMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .navigationTitle("添加交易")
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
                        saveTransaction()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showSymbolSearch) {
                SymbolSearchView { symbol, name, market in
                    symbolText = symbol
                    holdingName = name
                    selectedMarket = market
                    // 自动获取基準価額
                    if market == .JP_FUND {
                        Task { await fetchCurrentNAV() }
                    }
                }
            }
            .onChange(of: selectedMarket) { _, newMarket in
                // 投信自动切换为定額模式和fund类型
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

    // MARK: - Validation

    private var isValid: Bool {
        guard selectedPortfolio != nil,
              !symbolText.isEmpty,
              !holdingName.isEmpty else { return false }

        // 日期不能是未来
        if date > Date() { return false }

        if isMutualFund && investmentMode == .fixedAmount {
            // 定額模式: 需要投資金額和基準価額
            guard let amount = Double(investmentAmount), amount > 0,
                  let nav = Double(price), nav > 0 else { return false }
            // 投資金額验证 (100 ~ 1亿日元)
            guard amount >= 100 && amount <= 100_000_000 else { return false }
            return true
        } else {
            // 普通模式: 需要数量和价格
            guard let qty = Double(quantity), qty > 0,
                  let prc = Double(price), prc > 0 else { return false }
            // 价格合理性验证 (0.0001 ~ 10亿)
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
                if amount < 100 { return "投資金額至少100円" }
                if amount > 100_000_000 { return "投資金額超出范围" }
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
            // 静默失败，用户可手动输入
        }
    }

    // MARK: - Save

    private func saveTransaction() {
        guard let portfolio = selectedPortfolio else { return }

        let finalQuantity: Double
        let finalPrice: Double
        let feeAmount = Double(fee) ?? 0

        if isMutualFund && investmentMode == .fixedAmount {
            // 定額模式: 计算口数
            guard let amount = Double(investmentAmount),
                  let nav = Double(price), nav > 0 else { return }
            finalQuantity = amount / nav
            finalPrice = nav
        } else {
            // 普通模式
            guard let qty = Double(quantity),
                  let prc = Double(price) else { return }
            finalQuantity = qty
            finalPrice = prc
        }

        // Find or create holding
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

        dismiss()
    }
}

#Preview {
    AddTransactionView(portfolios: [])
        .modelContainer(for: Portfolio.self, inMemory: true)
}
