import SwiftUI
import SwiftData

/// 添加标的到关注列表（Watchlist）
struct AddToWatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let portfolio: Portfolio

    @State private var searchText = ""
    @State private var searchResults: [MarketDataService.SearchQuote] = []
    @State private var trendingStocks: [MarketDataService.TrendingStock] = []
    @State private var isSearching = false
    @State private var isLoadingTrending = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 搜索框
                    searchField

                    // 搜索结果或热门标的
                    if !searchText.isEmpty {
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
            }
            .task {
                await loadTrendingStocks()
            }
        }
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

            if searchResults.isEmpty && !isSearching {
                emptyResultsView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults, id: \.symbol) { result in
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

            if trendingStocks.isEmpty && !isLoadingTrending {
                loadingOrEmptyView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(trendingStocks, id: \.symbol) { stock in
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
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            let results = try await MarketDataService.shared.searchSymbol(query: query)
            await MainActor.run {
                searchResults = results
            }
        } catch {
            searchResults = []
        }
    }

    private func addSymbol(symbol: String, name: String, market: Market) {
        let holding = Holding(
            symbol: symbol,
            name: name,
            assetType: AssetType.stock.rawValue,
            market: market.rawValue
        )
        holding.portfolio = portfolio
        portfolio.holdings.append(holding)
        modelContext.insert(holding)

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        dismiss()
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
