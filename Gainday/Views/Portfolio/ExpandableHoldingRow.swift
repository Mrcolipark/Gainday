import SwiftUI
import SwiftData

/// 极简风格的可展开持仓行
struct ExpandableHoldingRow: View {
    @Environment(\.modelContext) private var modelContext
    let holding: Holding
    let quote: MarketDataService.QuoteData?
    let showPercent: Bool

    @State private var isExpanded = false
    @State private var selectedTab: ExpandedTab = .transactions
    @State private var showDeleteConfirm = false
    @State private var transactionToDelete: Transaction?
    @State private var transactionToEdit: Transaction?

    enum ExpandedTab {
        case transactions
        case addNew
        case edit
    }

    // MARK: - 计算属性

    private var displaySymbol: String {
        holding.symbol
            .replacingOccurrences(of: ".T", with: "")
            .replacingOccurrences(of: ".SS", with: "")
    }

    private var currentPrice: Double {
        quote?.regularMarketPrice ?? 0
    }

    private var previousClose: Double {
        quote?.regularMarketPreviousClose ?? currentPrice
    }

    private var dailyChangePercent: Double {
        guard previousClose > 0 else { return 0 }
        return ((currentPrice - previousClose) / previousClose) * 100
    }

    private var effectivePrice: Double {
        if let state = quote?.marketState {
            switch MarketState(rawValue: state) {
            case .pre, .prepre:
                return quote?.preMarketPrice ?? currentPrice
            case .post, .postpost:
                return quote?.postMarketPrice ?? currentPrice
            default:
                return currentPrice
            }
        }
        return currentPrice
    }

    private var marketValue: Double {
        effectivePrice * holding.totalQuantity
    }

    private var unrealizedPnL: Double {
        (effectivePrice - holding.averageCost) * holding.totalQuantity
    }

    private var unrealizedPnLPercent: Double {
        guard holding.averageCost > 0 else { return 0 }
        return (effectivePrice - holding.averageCost) / holding.averageCost * 100
    }

    private var isPositive: Bool {
        unrealizedPnL >= 0
    }

    private var sortedTransactions: [Transaction] {
        holding.transactions.sorted { $0.date > $1.date }
    }

    private var marketState: MarketState? {
        guard let stateStr = quote?.marketState else { return nil }
        return MarketState(rawValue: stateStr)
    }

    private var isUSStock: Bool {
        holding.marketEnum == .US
    }

    private var hasExtendedHoursData: Bool {
        guard isUSStock else { return false }
        switch marketState {
        case .pre, .prepre:
            return quote?.preMarketPrice != nil
        case .post, .postpost:
            return quote?.postMarketPrice != nil
        default:
            return false
        }
    }

    private var extendedHoursPrice: Double? {
        switch marketState {
        case .pre, .prepre:
            return quote?.preMarketPrice
        case .post, .postpost:
            return quote?.postMarketPrice
        default:
            return nil
        }
    }

    private var extendedHoursChangePercent: Double? {
        switch marketState {
        case .pre, .prepre:
            return quote?.preMarketChangePercent
        case .post, .postpost:
            return quote?.postMarketChangePercent
        default:
            return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            mainRow
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(AppAnimations.expandCollapse) {
                        isExpanded.toggle()
                    }
                }

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .liquidGlass(cornerRadius: 16)
        .alert("删除交易？", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let tx = transactionToDelete {
                    deleteTransaction(tx)
                }
            }
        } message: {
            Text("此操作无法撤销。")
        }
    }

    // MARK: - 主行

    private var mainRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displaySymbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    if let state = marketState, isUSStock, state != .regular && state != .closed {
                        MarketStateLabel(state: state)
                    }
                }

                Text("\(holding.totalQuantity.formattedQuantity)股 · \(holding.averageCost.compactCurrencyFormatted(code: holding.currency))")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(marketValue.compactCurrencyFormatted(code: holding.currency))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()

                HStack(spacing: 4) {
                    Text(showPercent ? unrealizedPnLPercent.percentFormatted() : unrealizedPnL.compactCurrencyFormatted(code: holding.currency, showSign: true))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(isPositive ? AppColors.profit : AppColors.loss)

                if hasExtendedHoursData, let extPrice = extendedHoursPrice,
                   let extPercent = extendedHoursChangePercent, let state = marketState {
                    HStack(spacing: 4) {
                        Text(state.displayName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(state.color)

                        Text(String(format: "%+.1f%%", extPercent))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(extPercent >= 0 ? AppColors.profit : AppColors.loss)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - 展开内容

    private var expandedContent: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.dividerColor)
                .frame(height: 1)
                .padding(.horizontal, 16)

            HStack(spacing: 8) {
                tabButton(title: "交易记录", tab: .transactions)
                tabButton(title: "添加", tab: .addNew)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Group {
                switch selectedTab {
                case .transactions:
                    transactionsList
                case .addNew:
                    InlineAddTransactionForm(
                        holding: holding,
                        editingTransaction: nil,
                        onSave: {
                            withAnimation {
                                selectedTab = .transactions
                            }
                        }
                    )
                case .edit:
                    if let tx = transactionToEdit {
                        InlineAddTransactionForm(
                            holding: holding,
                            editingTransaction: tx,
                            onSave: {
                                withAnimation {
                                    transactionToEdit = nil
                                    selectedTab = .transactions
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    private func tabButton(title: String, tab: ExpandedTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                .foregroundStyle(selectedTab == tab ? AppColors.textPrimary : AppColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    if selectedTab == tab {
                        Capsule()
                            .fill(AppColors.elevatedSurface)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 交易记录列表

    private var transactionsList: some View {
        VStack(spacing: 0) {
            if sortedTransactions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 24))
                        .foregroundStyle(AppColors.textTertiary)
                    Text("暂无交易记录")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                List {
                    ForEach(sortedTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                    showDeleteConfirm = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    transactionToEdit = transaction
                                    withAnimation {
                                        selectedTab = .edit
                                    }
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(minHeight: CGFloat(sortedTransactions.count) * 56)
            }
        }
        .padding(.top, 8)
    }

    private func deleteTransaction(_ transaction: Transaction) {
        modelContext.delete(transaction)
        do {
            try modelContext.save()
        } catch {
            ErrorPresenter.shared.showError(error)
        }
    }
}

// MARK: - 交易记录行

struct TransactionRow: View {
    let transaction: Transaction

    private var txType: TransactionType {
        TransactionType(rawValue: transaction.type) ?? .buy
    }

    var body: some View {
        HStack(spacing: 12) {
            // 类型指示
            Circle()
                .fill(txType.color.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: txType.iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(txType.color)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                Text(txType.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(transaction.quantity.formattedQuantity) × \(transaction.price.compactCurrencyFormatted(code: transaction.currency))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
                Text(transaction.totalAmount.compactCurrencyFormatted(code: transaction.currency))
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 内联添加交易表单

struct InlineAddTransactionForm: View {
    @Environment(\.modelContext) private var modelContext
    let holding: Holding
    let editingTransaction: Transaction?
    var onSave: (() -> Void)?

    @State private var transactionType: TransactionType = .buy
    @State private var date = Date()
    @State private var quantity = ""
    @State private var price = ""
    @State private var fee = ""
    @State private var isLoadingPrice = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var isEditMode: Bool {
        editingTransaction != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            if isEditMode {
                HStack {
                    Text("编辑交易")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                    Spacer()
                }
            }

            // 类型选择器
            HStack(spacing: 8) {
                ForEach([TransactionType.buy, .sell, .dividend], id: \.self) { type in
                    Button {
                        transactionType = type
                    } label: {
                        Text(type.displayName)
                            .font(.system(size: 13, weight: transactionType == type ? .semibold : .regular))
                            .foregroundStyle(transactionType == type ? type.color : AppColors.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if transactionType == type {
                                    Capsule()
                                        .fill(type.color.opacity(0.12))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            // 表单字段
            VStack(spacing: 12) {
                formRow(label: "日期") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .onChange(of: date) { _, _ in
                            fetchPriceForDate()
                        }
                }

                formRow(label: "数量") {
                    TextField("0", text: $quantity)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary)
                }

                formRow(label: "价格") {
                    HStack {
                        if isLoadingPrice {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        TextField("0.00", text: $price)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 15, design: .monospaced))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }

                formRow(label: "手续费") {
                    TextField("0", text: $fee)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }

            // 总计
            if let qty = Double(quantity), let prc = Double(price), qty > 0, prc > 0 {
                let feeValue = Double(fee) ?? 0
                let total = qty * prc + feeValue
                HStack {
                    Text("总计")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text(total.compactCurrencyFormatted(code: holding.currency))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()
                }
            }

            // 按钮
            HStack(spacing: 12) {
                Button {
                    if isEditMode {
                        onSave?()
                    } else {
                        clearForm()
                    }
                } label: {
                    Text(isEditMode ? "取消" : "清空")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppColors.elevatedSurface)
                        }
                }
                .buttonStyle(.plain)

                Button {
                    saveTransaction()
                } label: {
                    Text(isEditMode ? "更新" : "保存")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.accentColor)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!isValidInput)
                .opacity(isValidInput ? 1 : 0.5)
            }
        }
        .padding(.top, 14)
        .onAppear {
            if let tx = editingTransaction {
                transactionType = TransactionType(rawValue: tx.type) ?? .buy
                date = tx.date
                quantity = String(format: "%.2f", tx.quantity)
                price = String(format: "%.2f", tx.price)
                fee = tx.fee > 0 ? String(format: "%.2f", tx.fee) : ""
            }
        }
        .alert("错误", isPresented: $showError) {
            Button("确定") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            content()
        }
    }

    private var isValidInput: Bool {
        guard let qty = Double(quantity), qty > 0 else { return false }
        guard let prc = Double(price), prc > 0 else { return false }
        return true
    }

    private func clearForm() {
        quantity = ""
        price = ""
        fee = ""
        date = Date()
        transactionType = .buy
    }

    private func saveTransaction() {
        guard let qty = Double(quantity), let prc = Double(price) else { return }
        let feeValue = Double(fee) ?? 0

        if let existingTransaction = editingTransaction {
            existingTransaction.type = transactionType.rawValue
            existingTransaction.date = date
            existingTransaction.quantity = qty
            existingTransaction.price = prc
            existingTransaction.fee = feeValue
        } else {
            let transaction = Transaction(
                type: transactionType.rawValue,
                date: date,
                quantity: qty,
                price: prc,
                fee: feeValue,
                currency: holding.currency
            )

            modelContext.insert(transaction)
            holding.transactions.append(transaction)
        }

        do {
            try modelContext.save()
            clearForm()
            onSave?()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func fetchPriceForDate() {
        guard date < Date() else { return }

        isLoadingPrice = true

        Task {
            do {
                let chartData = try await MarketDataService.shared.fetchChartData(
                    symbol: holding.symbol,
                    interval: "1d",
                    range: "1mo"
                )

                let calendar = Calendar.current
                let targetDate = calendar.startOfDay(for: date)

                if let matchingPrice = chartData.first(where: {
                    calendar.isDate(calendar.startOfDay(for: $0.date), inSameDayAs: targetDate)
                }) {
                    await MainActor.run {
                        price = String(format: "%.2f", matchingPrice.close)
                        isLoadingPrice = false
                    }
                } else if let latestPrice = chartData.last {
                    await MainActor.run {
                        price = String(format: "%.2f", latestPrice.close)
                        isLoadingPrice = false
                    }
                } else {
                    await MainActor.run {
                        isLoadingPrice = false
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingPrice = false
                }
            }
        }
    }
}

#Preview {
    List {
        ExpandableHoldingRow(
            holding: Holding(symbol: "AAPL", name: "Apple Inc.", market: Market.US.rawValue),
            quote: nil,
            showPercent: true
        )
    }
    .modelContainer(for: [Holding.self, Transaction.self], inMemory: true)
}
