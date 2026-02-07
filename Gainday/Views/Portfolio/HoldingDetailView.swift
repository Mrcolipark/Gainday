import SwiftUI

struct HoldingDetailView: View {
    let holding: Holding
    let quote: MarketDataService.QuoteData?

    @Environment(\.dismiss) private var dismiss
    @State private var chartData: [PriceCacheData] = []
    @State private var isLoadingChart = false
    @State private var selectedTimeRange: TimeRange = .threeMonths
    @State private var selectedTab = 0
    @State private var detailedQuote: MarketDataService.QuoteData?
    @State private var isChartInteracting = false

    // 使用详细数据（如果可用）或传入的基础数据
    private var displayQuote: MarketDataService.QuoteData? {
        detailedQuote ?? quote
    }

    private var currentPrice: Double {
        displayQuote?.regularMarketPrice ?? 0
    }

    private var dailyChange: Double {
        displayQuote?.regularMarketChange ?? 0
    }

    private var dailyChangePercent: Double {
        displayQuote?.regularMarketChangePercent ?? 0
    }

    private var unrealizedPnL: Double {
        (currentPrice - holding.averageCost) * holding.totalQuantity
    }

    private var unrealizedPnLPercent: Double {
        holding.averageCost > 0 ? ((currentPrice - holding.averageCost) / holding.averageCost) * 100 : 0
    }

    private var isPositive: Bool {
        dailyChange >= 0
    }

    private var marketState: MarketState? {
        guard let stateStr = quote?.marketState else { return nil }
        return MarketState(rawValue: stateStr)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 头部：价格信息
                headerSection

                // 图表
                chartSection

                // 分段选择器
                tabSelector

                // 内容区域
                switch selectedTab {
                case 0:
                    summarySection
                case 1:
                    positionSection
                case 2:
                    transactionsSection
                default:
                    EmptyView()
                }
            }
            .padding()
        }
        .background(AppColors.background)
        .navigationTitle(holding.symbol)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            // 并行加载详细报价和图表
            async let quoteTask: () = loadDetailedQuote()
            async let chartTask: () = loadChartData()
            _ = await (quoteTask, chartTask)
        }
    }

    private func loadDetailedQuote() async {
        do {
            let detailed = try await MarketDataService.shared.fetchDetailedQuote(symbol: holding.symbol)
            await MainActor.run { detailedQuote = detailed }
        } catch {
            print("[HoldingDetailView] Failed to load detailed quote: \(error)")
        }
    }

    // MARK: - 头部信息

    private var headerSection: some View {
        VStack(spacing: 16) {
            // 股票名称和市场状态
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.symbol)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(holding.name)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if let state = marketState {
                    MarketStateLabel(state: state)
                }
            }

            // 当前价格
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(currentPrice.currencyFormatted(code: holding.currency))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()

                Spacer()

                // 涨跌幅徽章
                VStack(alignment: .trailing, spacing: 4) {
                    Text(dailyChange.currencyFormatted(code: holding.currency, showSign: true))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isPositive ? AppColors.profit : AppColors.loss)

                    Text(dailyChangePercent.percentFormatted())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isPositive ? AppColors.profit : AppColors.loss)
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - 图表

    private var chartSection: some View {
        VStack(spacing: 12) {
            // 时间范围选择
            timeRangeSelector

            // 交互式图表
            if isLoadingChart {
                ProgressView()
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
            } else {
                InteractiveStockChart(
                    data: chartData,
                    currency: holding.currency,
                    timeRange: selectedTimeRange,
                    isInteracting: $isChartInteracting
                )
                .frame(height: 250)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
        .disableSwipeBack(when: isChartInteracting)
    }

    private var timeRangeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button {
                        selectedTimeRange = range
                        Task { await loadChartData() }
                    } label: {
                        Text(range.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(selectedTimeRange == range ? .white : AppColors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedTimeRange == range ? AppColors.accent : AppColors.elevatedSurface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - 分段选择器

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(["概览".localized, "持仓".localized, "交易记录".localized].indices, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                } label: {
                    Text(["概览".localized, "持仓".localized, "交易记录".localized][index])
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(selectedTab == index ? AppColors.textPrimary : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == index ?
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppColors.elevatedSurface) : nil
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - 概览

    private var summarySection: some View {
        VStack(spacing: 12) {
            // 基本数据
            statsGrid([
                ("开盘".localized, formatPrice(displayQuote?.regularMarketOpen)),
                ("昨收".localized, formatPrice(displayQuote?.regularMarketPreviousClose)),
                ("最高".localized, formatPrice(displayQuote?.regularMarketDayHigh)),
                ("最低".localized, formatPrice(displayQuote?.regularMarketDayLow)),
            ])

            statsGrid([
                ("成交量".localized, formatVolume(displayQuote?.regularMarketVolume)),
                ("市值".localized, formatMarketCap(displayQuote?.marketCap)),
                ("市盈率".localized, formatPE(displayQuote?.trailingPE)),
                ("股息率".localized, formatDividend(displayQuote?.dividendYield)),
            ])

            statsGrid([
                ("每股收益".localized, formatEPS(displayQuote?.epsTrailingTwelveMonths)),
                ("52周最高".localized, formatPrice(displayQuote?.fiftyTwoWeekHigh)),
            ])

            statsGrid([
                ("52周最低".localized, formatPrice(displayQuote?.fiftyTwoWeekLow)),
            ])
        }
    }

    private func formatPrice(_ value: Double?) -> String {
        guard let v = value, v > 0 else { return "-" }
        return v.currencyFormatted(code: holding.currency)
    }

    private func formatVolume(_ value: Double?) -> String {
        guard let v = value, v > 0 else { return "-" }
        return v.compactFormatted()
    }

    private func formatMarketCap(_ value: Double?) -> String {
        guard let v = value, v > 0 else { return "-" }
        return v.compactFormatted()
    }

    private func formatEPS(_ value: Double?) -> String {
        guard let v = value else { return "-" }
        return String(format: "%.2f", v)
    }

    private func statsGrid(_ items: [(String, String)]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 1) {
            ForEach(items, id: \.0) { item in
                HStack {
                    Text(item.0)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text(item.1)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private func formatPE(_ pe: Double?) -> String {
        guard let pe = pe, pe > 0 else { return "-" }
        return String(format: "%.2f", pe)
    }

    private func formatDividend(_ yield: Double?) -> String {
        guard let yield = yield, yield > 0 else { return "-" }
        return String(format: "%.2f%%", yield * 100)
    }

    // MARK: - 持仓

    private var positionSection: some View {
        VStack(spacing: 12) {
            // 持仓信息
            VStack(spacing: 0) {
                positionRow("持有数量".localized, holding.totalQuantity.formattedQuantity)
                Divider().background(AppColors.dividerColor)
                positionRow("平均成本".localized, holding.averageCost.currencyFormatted(code: holding.currency))
                Divider().background(AppColors.dividerColor)
                positionRow("总成本".localized, holding.totalCost.currencyFormatted(code: holding.currency))
                Divider().background(AppColors.dividerColor)
                positionRow("持仓价值".localized, (currentPrice * holding.totalQuantity).currencyFormatted(code: holding.currency))
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )

            // 盈亏卡片 - 未实现
            if holding.totalQuantity > 0 {
                pnlCard(
                    title: "未实现盈亏".localized,
                    amount: unrealizedPnL,
                    percent: unrealizedPnLPercent
                )
            }

            // 盈亏卡片 - 已实现（如果有卖出交易）
            if holding.realizedPnL != 0 {
                pnlCard(
                    title: "已实现盈亏".localized,
                    amount: holding.realizedPnL,
                    percent: nil
                )
            }

            // 股息
            if holding.totalDividends > 0 {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.profit)
                        Text("累计股息".localized)
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Text(holding.totalDividends.currencyFormatted(code: holding.currency))
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColors.profit)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
            }

            // 总收益汇总（如果有多种收益）
            if hasMixedPnL {
                totalPnLSummary
            }
        }
    }

    private func positionRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func pnlCard(title: String, amount: Double, percent: Double?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)

                Text(amount.currencyFormatted(code: holding.currency, showSign: true))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(amount >= 0 ? AppColors.profit : AppColors.loss)
            }

            Spacer()

            if let percent = percent {
                Text(percent.percentFormatted())
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(amount >= 0 ? AppColors.profit : AppColors.loss)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private var hasMixedPnL: Bool {
        let hasUnrealized = holding.totalQuantity > 0 && unrealizedPnL != 0
        let hasRealized = holding.realizedPnL != 0
        let hasDividends = holding.totalDividends > 0
        // 至少有两种收益类型时显示汇总
        return [hasUnrealized, hasRealized, hasDividends].filter { $0 }.count >= 2
    }

    private var totalPnL: Double {
        var total = holding.realizedPnL + holding.totalDividends
        if holding.totalQuantity > 0 {
            total += unrealizedPnL
        }
        return total
    }

    private var totalPnLSummary: some View {
        VStack(spacing: 8) {
            HStack {
                Text("总收益".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(totalPnL.currencyFormatted(code: holding.currency, showSign: true))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(totalPnL >= 0 ? AppColors.profit : AppColors.loss)
            }

            Divider().background(AppColors.dividerColor)

            // 收益明细
            VStack(spacing: 6) {
                if holding.totalQuantity > 0 && unrealizedPnL != 0 {
                    summaryDetailRow("未实现".localized, unrealizedPnL)
                }
                if holding.realizedPnL != 0 {
                    summaryDetailRow("已实现".localized, holding.realizedPnL)
                }
                if holding.totalDividends > 0 {
                    summaryDetailRow("股息".localized, holding.totalDividends)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private func summaryDetailRow(_ label: String, _ amount: Double) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textTertiary)
            Spacer()
            Text(amount.currencyFormatted(code: holding.currency, showSign: true))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(amount >= 0 ? AppColors.profit.opacity(0.8) : AppColors.loss.opacity(0.8))
        }
    }

    // MARK: - 交易记录

    private var transactionsSection: some View {
        let sorted = holding.transactions.sorted { $0.date > $1.date }

        return VStack(spacing: 0) {
            if sorted.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.textTertiary)
                    Text("暂无交易记录".localized)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
            } else {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, tx in
                    transactionRow(tx)

                    if index < sorted.count - 1 {
                        Divider()
                            .background(AppColors.dividerColor)
                            .padding(.leading, 56)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
            }
        }
    }

    private func transactionRow(_ tx: Transaction) -> some View {
        HStack(spacing: 12) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(tx.transactionType == .buy ? AppColors.profit.opacity(0.15) :
                            tx.transactionType == .sell ? AppColors.loss.opacity(0.15) :
                            AppColors.textTertiary.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: tx.transactionType.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tx.transactionType == .buy ? AppColors.profit :
                                        tx.transactionType == .sell ? AppColors.loss :
                                        AppColors.textSecondary)
            }

            // 信息
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.transactionType.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)

                Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textTertiary)
            }

            Spacer()

            // 数量和价格
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(tx.quantity.formattedQuantity)\("股".localized)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)

                Text("@ \(tx.price.currencyFormatted(code: tx.currency))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 数据加载

    private func loadChartData() async {
        isLoadingChart = true
        defer { isLoadingChart = false }

        do {
            chartData = try await MarketDataService.shared.fetchChartData(
                symbol: holding.symbol,
                interval: selectedTimeRange.yahooInterval,
                range: selectedTimeRange.yahooRange
            )
        } catch {
            chartData = []
        }
    }
}

#Preview {
    NavigationStack {
        HoldingDetailView(
            holding: Holding(symbol: "AAPL", name: "Apple Inc.", market: Market.US.rawValue),
            quote: nil
        )
    }
    .preferredColorScheme(.dark)
}
