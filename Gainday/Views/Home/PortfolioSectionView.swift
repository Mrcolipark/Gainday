import SwiftUI

/// iPhone 股票 App 风格的投资组合区块
struct PortfolioSectionView: View {
    let portfolioPnL: PnLCalculationService.PortfolioPnL
    let quotes: [String: MarketDataService.QuoteData]
    let displayMode: PortfolioDisplayMode
    let showPercent: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    var onRefresh: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var animateIn = false
    @State private var selectedHolding: Holding?
    @State private var showHoldingDetail = false
    @State private var showAddTransaction = false
    @State private var showAddToWatchlist = false
    @State private var holdingToDelete: Holding?
    @State private var showDeleteConfirm = false

    private var portfolio: Portfolio {
        portfolioPnL.portfolio
    }

    private var isPositive: Bool {
        portfolioPnL.dailyPnL >= 0
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onToggle()
                    }
                }

            if isExpanded {
                holdingsContent
                    .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
        .opacity(animateIn ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                animateIn = true
            }
        }
        .sheet(isPresented: $showHoldingDetail) {
            if let holding = selectedHolding {
                NavigationStack {
                    HoldingDetailView(
                        holding: holding,
                        quote: quotes[holding.symbol]
                    )
                }
            }
        }
        .sheet(isPresented: $showAddTransaction, onDismiss: {
            onRefresh?()
        }) {
            AddTransactionView(portfolios: [portfolio])
        }
        .sheet(isPresented: $showAddToWatchlist, onDismiss: {
            onRefresh?()
        }) {
            AddToWatchlistView(portfolio: portfolio)
        }
        .alert("确认删除".localized, isPresented: $showDeleteConfirm) {
            Button("取消".localized, role: .cancel) {
                holdingToDelete = nil
            }
            Button("删除".localized, role: .destructive) {
                if let holding = holdingToDelete {
                    deleteHolding(holding)
                }
            }
        } message: {
            if let holding = holdingToDelete {
                Text("确定要删除 \(holding.symbol) 吗？所有交易记录也将被删除。")
            }
        }
    }

    // MARK: - 删除持仓

    private func deleteHolding(_ holding: Holding) {
        // 删除所有关联的交易记录
        for transaction in holding.transactions {
            modelContext.delete(transaction)
        }
        // 从账户中移除
        if let index = portfolio.holdings.firstIndex(where: { $0.id == holding.id }) {
            portfolio.holdings.remove(at: index)
        }
        // 删除持仓
        modelContext.delete(holding)

        do {
            try modelContext.save()
            onRefresh?()
        } catch {
            print("删除持仓失败: \(error)")
        }

        holdingToDelete = nil
    }

    /// 根据当前模式显示添加视图
    private func showAddView() {
        if displayMode == .holdings {
            showAddTransaction = true
        } else {
            showAddToWatchlist = true
        }
    }

    // MARK: - 区块头部

    private var sectionHeader: some View {
        HStack(spacing: 12) {
            // 账户颜色标识
            Circle()
                .fill(portfolio.tagColor)
                .frame(width: 10, height: 10)

            // 账户名称
            VStack(alignment: .leading, spacing: 2) {
                Text(portfolio.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("\(portfolio.holdings.count) \("持仓".localized)")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            // 数值 - 使用紧凑格式避免换行
            Text(portfolioPnL.totalValue.compactCurrencyFormatted(code: portfolio.baseCurrency))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // 涨跌幅徽章
            Text(portfolioPnL.dailyPnLPercent.percentFormatted())
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(minWidth: 65)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isPositive ? AppColors.profit : AppColors.loss)
                )

            // 展开/收起箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    // MARK: - 持仓内容

    @ViewBuilder
    private var holdingsContent: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.dividerColor)
                .frame(height: 1)
                .padding(.horizontal, 16)

            switch displayMode {
            case .basic:
                basicModeContent

            case .details:
                detailsModeContent

            case .holdings:
                holdingsModeContent
            }
        }
    }

    // MARK: - Basic 模式内容

    private var basicModeContent: some View {
        VStack(spacing: 0) {
            if portfolioPnL.holdingPnLs.isEmpty {
                emptyHoldingsState
            } else {
                List {
                    ForEach(portfolioPnL.holdingPnLs, id: \.holding.id) { holdingPnL in
                        NavigationLink {
                            HoldingDetailView(
                                holding: holdingPnL.holding,
                                quote: quotes[holdingPnL.holding.symbol]
                            )
                        } label: {
                            HoldingRow(
                                holding: holdingPnL.holding,
                                quote: quotes[holdingPnL.holding.symbol],
                                displayMode: .basic,
                                showPercent: showPercent
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                holdingToDelete = holdingPnL.holding
                                showDeleteConfirm = true
                            } label: {
                                Label("删除".localized, systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(portfolioPnL.holdingPnLs.count) * 56)

                addHoldingButton
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Details 模式内容

    private var detailsModeContent: some View {
        let holdings = portfolioPnL.holdingPnLs.map(\.holding)
        // 计算表格高度：表头36 + 分隔线1 + 每行(44+1分隔线) - 最后一行无分隔线
        let tableHeight: CGFloat = 36 + 1 + CGFloat(holdings.count) * 45 - (holdings.isEmpty ? 0 : 1)

        return VStack(spacing: 8) {
            if holdings.isEmpty {
                emptyHoldingsState
            } else {
                HoldingDetailsTable(
                    holdings: holdings,
                    quotes: quotes,
                    showPercent: showPercent,
                    onHoldingTap: { holding in
                        selectedHolding = holding
                        showHoldingDetail = true
                    },
                    onHoldingDelete: { holding in
                        holdingToDelete = holding
                        showDeleteConfirm = true
                    }
                )
                .frame(height: tableHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                addHoldingButton
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Holdings 模式内容

    private var holdingsModeContent: some View {
        VStack(spacing: 8) {
            if portfolioPnL.holdingPnLs.isEmpty {
                emptyHoldingsState
            } else {
                List {
                    ForEach(portfolioPnL.holdingPnLs, id: \.holding.id) { holdingPnL in
                        ExpandableHoldingRow(
                            holding: holdingPnL.holding,
                            quote: quotes[holdingPnL.holding.symbol],
                            showPercent: showPercent
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                holdingToDelete = holdingPnL.holding
                                showDeleteConfirm = true
                            } label: {
                                Label("删除".localized, systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(portfolioPnL.holdingPnLs.count) * 80)

                addHoldingButton
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    // MARK: - 共享组件

    private var addButtonTitle: String {
        displayMode == .holdings ? "添加持仓".localized : "添加标的".localized
    }

    private var emptyStateTitle: String {
        displayMode == .holdings ? "暂无持仓".localized : "暂无标的".localized
    }

    private var emptyHoldingsState: some View {
        VStack(spacing: 12) {
            Image(systemName: displayMode == .holdings ? "chart.line.uptrend.xyaxis" : "star")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.textTertiary)

            Text(emptyStateTitle)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.textSecondary)

            Button {
                showAddView()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text(addButtonTitle)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppColors.profit)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var addHoldingButton: some View {
        Button {
            showAddView()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text(addButtonTitle)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.dividerColor, lineWidth: 1)
            )
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                Text("需要 SwiftData 上下文预览")
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding()
        }
    }
}
