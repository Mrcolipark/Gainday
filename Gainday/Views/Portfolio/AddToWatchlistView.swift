import SwiftUI
import SwiftData

/// 添加标的到关注列表（Watchlist）
struct AddToWatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let portfolio: Portfolio

    @State private var searchText = ""
    @State private var searchResults: [MarketDataService.SearchQuote] = []
    @State private var fundResults: [JapanFundService.FundSearchResult] = []
    @State private var trendingStocks: [MarketDataService.TrendingStock] = []
    @State private var isSearching = false
    @State private var isLoadingTrending = false

    /// 当前账户类型
    private var accountType: AccountType {
        portfolio.accountTypeEnum
    }

    /// 允许的市场
    private var allowedMarkets: [Market] {
        accountType.allowedMarkets
    }

    /// 是否只能添加投信（つみたて账户）
    private var fundsOnly: Bool {
        accountType == .nisa_tsumitate
    }

    /// 是否需要过滤つみたて対象商品
    private var filterTsumitateEligible: Bool {
        accountType.requiresTsumitateEligible
    }

    /// 过滤后的搜索结果（按市场过滤）
    private var filteredSearchResults: [MarketDataService.SearchQuote] {
        searchResults.filter { result in
            let market = detectMarket(result.symbol)
            return allowedMarkets.contains(market)
        }
    }

    /// 过滤后的基金结果
    private var filteredFundResults: [JapanFundService.FundSearchResult] {
        guard filterTsumitateEligible else { return fundResults }
        return fundResults.filter { $0.isTsumitateEligible }
    }

    /// 过滤后的热门标的（按市场过滤）
    private var filteredTrendingStocks: [MarketDataService.TrendingStock] {
        trendingStocks.filter { stock in
            allowedMarkets.contains(stock.market)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // NISA 账户类型提示
                    if accountType.isNISA {
                        nisaAccountHint
                    }

                    // 搜索框
                    searchField

                    // 搜索结果或热门标的
                    if fundsOnly {
                        // つみたて账户只显示投信
                        fundResultsList
                    } else if !searchText.isEmpty {
                        searchResultsList
                    } else {
                        trendingStocksList
                    }
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("添加标的".localized)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消".localized) { dismiss() }
                        .foregroundStyle(AppColors.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成".localized) { dismiss() }
                        .foregroundStyle(AppColors.profit)
                        .fontWeight(.semibold)
                }
            }
            .task {
                if fundsOnly {
                    // つみたて账户加载热门基金
                    fundResults = JapanFundService.popularFunds
                } else {
                    await loadTrendingStocks()
                }
            }
        }
    }

    // MARK: - NISA 账户提示

    private var nisaAccountHint: some View {
        HStack(spacing: 8) {
            Image(systemName: accountType.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accountType.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(accountType.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                if fundsOnly {
                    Text("只能买入対象商品".localized)
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accountType.color.opacity(0.1))
        )
    }

    // MARK: - 搜索框

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(AppColors.textTertiary)

            TextField(
                "",
                text: $searchText,
                prompt: Text("搜索股票代码或名称".localized)
                    .foregroundStyle(AppColors.textTertiary)
            )
            .font(.system(size: 16))
            .foregroundStyle(AppColors.textPrimary)
            #if os(iOS)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            #endif

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
        .onChange(of: searchText) { _, newValue in
            Task {
                await performSearch(query: newValue)
            }
        }
    }

    // MARK: - 搜索结果

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("搜索结果".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)

            if filteredSearchResults.isEmpty && !isSearching {
                emptyResultsView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredSearchResults, id: \.symbol) { result in
                        searchResultRow(result)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
            }
        }
    }

    // MARK: - 基金搜索结果（つみたて账户专用）

    private var fundResultsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 搜索提示
            if filterTsumitateEligible {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AccountType.nisa_tsumitate.color)

                    Text("つみたてNISA対象商品".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()
                }
            }

            if filteredFundResults.isEmpty && !isSearching {
                if searchText.isEmpty {
                    popularFundsView
                } else {
                    emptyFundResultsView
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredFundResults, id: \.code) { fund in
                        fundResultRow(fund)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
            }
        }
    }

    private func fundResultRow(_ fund: JapanFundService.FundSearchResult) -> some View {
        let isAlreadyAdded = portfolio.holdings.contains { $0.symbol == fund.code }

        return Button {
            if !isAlreadyAdded {
                addFund(fund)
            }
        } label: {
            HStack(spacing: 12) {
                // 対象商品标记
                if fund.isTsumitateEligible {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AccountType.nisa_tsumitate.color)
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textTertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(fund.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                    Text(fund.code)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                if isAlreadyAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.profit)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.dividerColor)
                .frame(height: 1)
                .padding(.leading, 48)
        }
    }

    private var popularFundsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("人气基金".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)

            LazyVStack(spacing: 0) {
                ForEach(filteredFundResults, id: \.code) { fund in
                    fundResultRow(fund)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    private var emptyFundResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.textTertiary)
            Text("未找到つみたてNISA対象商品".localized)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.textSecondary)
            Text("请尝试搜索其他基金代码".localized)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private func searchResultRow(_ result: MarketDataService.SearchQuote) -> some View {
        let isAlreadyAdded = portfolio.holdings.contains { $0.symbol == result.symbol }
        let displayName = result.longname ?? result.shortname ?? result.symbol
        let market = detectMarket(result.symbol)

        return Button {
            if !isAlreadyAdded {
                addSymbol(symbol: result.symbol, name: displayName, market: market)
            }
        } label: {
            HStack(spacing: 12) {
                Text(market.flag)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(displayName)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if isAlreadyAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.profit)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.dividerColor)
                .frame(height: 1)
                .padding(.leading, 56)
        }
    }

    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.textTertiary)
            Text("未找到相关标的".localized)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - 热门标的

    private var trendingStocksList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("热门标的".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                if isLoadingTrending {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(AppColors.textSecondary)
                }
            }

            if filteredTrendingStocks.isEmpty && !isLoadingTrending {
                loadingOrEmptyView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredTrendingStocks, id: \.symbol) { stock in
                        trendingStockRow(stock)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
            }
        }
    }

    private func trendingStockRow(_ stock: MarketDataService.TrendingStock) -> some View {
        let isAlreadyAdded = portfolio.holdings.contains { $0.symbol == stock.symbol }

        return Button {
            if !isAlreadyAdded {
                addSymbol(symbol: stock.symbol, name: stock.name, market: stock.market)
            }
        } label: {
            HStack(spacing: 12) {
                Text(stock.market.flag)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    Text(stock.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(stock.name)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // 价格和涨跌幅
                VStack(alignment: .trailing, spacing: 2) {
                    Text(stock.price.formatted(.number.precision(.fractionLength(2))))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(stock.changePercent.percentFormatted())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(stock.changePercent >= 0 ? AppColors.profit : AppColors.loss)
                }

                if isAlreadyAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.profit)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if stock.symbol != trendingStocks.last?.symbol {
                Rectangle()
                    .fill(AppColors.dividerColor)
                    .frame(height: 1)
                    .padding(.leading, 56)
            }
        }
    }

    private var loadingOrEmptyView: some View {
        VStack(spacing: 12) {
            if isLoadingTrending {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(AppColors.profit)
                Text("加载热门标的...".localized)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32))
                    .foregroundStyle(AppColors.textTertiary)
                Text("暂无热门标的".localized)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - Actions

    private func loadTrendingStocks() async {
        isLoadingTrending = true
        defer { isLoadingTrending = false }

        do {
            let stocks = try await MarketDataService.shared.fetchTrendingSymbols(regions: ["US", "JP", "HK"])
            await MainActor.run {
                // 排序：按涨跌幅绝对值排序，最热门的在前
                trendingStocks = stocks.sorted { abs($0.changePercent) > abs($1.changePercent) }
            }
        } catch {
            #if DEBUG
            print("Failed to load trending stocks: \(error)")
            #endif
        }
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            fundResults = fundsOnly ? JapanFundService.popularFunds : []
            return
        }

        isSearching = true
        defer { isSearching = false }

        if fundsOnly {
            // つみたて账户搜索基金
            do {
                let results = try await JapanFundService.shared.searchFunds(query: query)
                await MainActor.run {
                    fundResults = results
                }
            } catch {
                fundResults = []
            }
        } else {
            // 普通搜索股票
            do {
                let results = try await MarketDataService.shared.searchSymbol(query: query)
                await MainActor.run {
                    searchResults = results
                }
            } catch {
                searchResults = []
            }
        }
    }

    private func addSymbol(symbol: String, name: String, market: Market) {
        let holding = Holding(
            symbol: symbol,
            name: name,
            assetType: AssetType.stock.rawValue,
            market: market.rawValue,
            accountType: accountType.rawValue
        )
        holding.portfolio = portfolio
        portfolio.holdings.append(holding)
        modelContext.insert(holding)

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func addFund(_ fund: JapanFundService.FundSearchResult) {
        let holding = Holding(
            symbol: fund.code,
            name: fund.name,
            assetType: AssetType.fund.rawValue,
            market: Market.JP_FUND.rawValue,
            accountType: accountType.rawValue
        )
        holding.portfolio = portfolio
        portfolio.holdings.append(holding)
        modelContext.insert(holding)

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func detectMarket(_ symbol: String) -> Market {
        if symbol.hasSuffix(".T") { return .JP }
        if symbol.hasSuffix(".HK") { return .HK }
        if symbol.hasSuffix(".SS") || symbol.hasSuffix(".SZ") { return .CN }
        return .US
    }
}

#Preview {
    AddToWatchlistView(portfolio: Portfolio(name: "Test"))
        .preferredColorScheme(.dark)
}
