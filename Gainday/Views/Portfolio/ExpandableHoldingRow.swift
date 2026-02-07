import SwiftUI
import SwiftData

/// 极简风格的可展开持仓行
struct ExpandableHoldingRow: View {
    @Environment(\.modelContext) private var modelContext
    let holding: Holding
    let quote: MarketDataService.QuoteData?
    let showPercent: Bool
    var scrollProxy: ScrollViewProxy?

    @State private var isExpanded = false
    @State private var showDeleteConfirm = false
    @State private var transactionToDelete: Transaction?
    @State private var transactionToEdit: Transaction?
    @State private var showAddTransaction = false

    /// 用于滚动定位的 ID
    private var rowId: String {
        "holding-\(holding.id.uuidString)"
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
        switch extendedHoursType {
        case .pre:
            return quote?.preMarketPrice ?? currentPrice
        case .post:
            return quote?.postMarketPrice ?? currentPrice
        default:
            return currentPrice
        }
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

    /// 确定显示哪种盘前/盘后数据（nil = 不显示）
    private var extendedHoursType: MarketState? {
        guard isUSStock else { return nil }
        switch marketState {
        case .pre, .prepre:
            return quote?.preMarketPrice != nil ? .pre : nil
        case .post, .postpost:
            return quote?.postMarketPrice != nil ? .post : nil
        case .closed:
            if quote?.postMarketPrice != nil { return .post }
            if quote?.preMarketPrice != nil { return .pre }
            return nil
        default:
            return nil
        }
    }

    private var hasExtendedHoursData: Bool {
        extendedHoursType != nil
    }

    private var extendedHoursPrice: Double? {
        switch extendedHoursType {
        case .pre:
            return quote?.preMarketPrice
        case .post:
            return quote?.postMarketPrice
        default:
            return nil
        }
    }

    private var extendedHoursChangePercent: Double? {
        switch extendedHoursType {
        case .pre:
            return quote?.preMarketChangePercent
        case .post:
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
                    // 展开时滚动到该行，确保展开内容可见
                    if isExpanded {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                scrollProxy?.scrollTo(rowId, anchor: .top)
                            }
                        }
                    }
                }

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .id(rowId)
        .liquidGlass(cornerRadius: 16)
        .alert("删除交易？".localized, isPresented: $showDeleteConfirm) {
            Button("取消".localized, role: .cancel) {}
            Button("删除".localized, role: .destructive) {
                if let tx = transactionToDelete {
                    deleteTransaction(tx)
                }
            }
        } message: {
            Text("此操作无法撤销。".localized)
        }
        .sheet(item: $transactionToEdit) { tx in
            EditTransactionView(transaction: tx)
        }
        .sheet(isPresented: $showAddTransaction) {
            if let portfolio = holding.portfolio {
                AddTransactionView(portfolios: [portfolio], existingHolding: holding)
            }
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

                Text("\(holding.totalQuantity.formattedQuantity)\("股".localized) · \(holding.averageCost.compactCurrencyFormatted(code: holding.currency))")
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
                   let extPercent = extendedHoursChangePercent, let state = extendedHoursType {
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

            // 添加交易按钮
            Button {
                showAddTransaction = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                    Text("添加交易".localized)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(AppColors.profit)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            transactionsList
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
    }

    // MARK: - 交易记录列表

    private var transactionsList: some View {
        VStack(spacing: 0) {
            if sortedTransactions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 24))
                        .foregroundStyle(AppColors.textTertiary)
                    Text("暂无交易记录".localized)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // 使用 VStack 替代 List，避免嵌套滚动问题
                VStack(spacing: 0) {
                    ForEach(sortedTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button {
                                    transactionToEdit = transaction
                                } label: {
                                    Label("编辑".localized, systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                    showDeleteConfirm = true
                                } label: {
                                    Label("删除".localized, systemImage: "trash")
                                }
                            }

                        if transaction.id != sortedTransactions.last?.id {
                            Rectangle()
                                .fill(AppColors.dividerColor)
                                .frame(height: 1)
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func deleteTransaction(_ transaction: Transaction) {
        modelContext.delete(transaction)
        do {
            try modelContext.save()
            // 通知日历视图刷新
            NotificationCenter.default.post(name: .portfolioDataDidChange, object: nil)
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
