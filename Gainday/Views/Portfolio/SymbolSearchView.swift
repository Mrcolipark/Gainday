import SwiftUI

/// 标的搜索页面 - 统一设计语言
struct SymbolSearchView: View {
    @Environment(\.dismiss) private var dismiss

    /// 账户类型（用于过滤市场和商品）
    let accountType: AccountType?
    let onSelect: (String, String, Market) -> Void

    @State private var searchText = ""
    @State private var results: [MarketDataService.SearchQuote] = []
    @State private var fundResults: [JapanFundService.FundSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var searchMode: SearchMode = .stocks

    /// 初始化（带账户类型过滤）
    init(accountType: AccountType? = nil, onSelect: @escaping (String, String, Market) -> Void) {
        self.accountType = accountType
        self.onSelect = onSelect

        // つみたて账户默认显示投信搜索
        if accountType == .nisa_tsumitate {
            _searchMode = State(initialValue: .funds)
        }
    }

    /// 是否只能搜索投信（つみたて账户）
    private var fundsOnly: Bool {
        accountType == .nisa_tsumitate
    }

    /// 是否需要过滤つみたて対象商品
    private var filterTsumitateEligible: Bool {
        accountType?.requiresTsumitateEligible ?? false
    }

    /// 过滤后的基金结果
    private var filteredFundResults: [JapanFundService.FundSearchResult] {
        guard filterTsumitateEligible else { return fundResults }
        return fundResults.filter { $0.isTsumitateEligible }
    }

    enum SearchMode: CaseIterable {
        case stocks
        case funds

        var displayName: String {
            switch self {
            case .stocks: return "股票/ETF".localized
            case .funds: return "日本投信".localized
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 搜索框
                    searchField

                    // 搜索类型选择
                    searchModeSelector

                    // 搜索结果
                    if isSearching {
                        loadingView
                    } else if searchMode == .stocks {
                        stockResultsList
                    } else {
                        fundResultsList
                    }
                }
                .padding(16)
            }
            .background(AppColors.background)
            .navigationTitle("搜索标的".localized)
            #if os(iOS)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消".localized) { dismiss() }
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
            .task {
                // 初始加载热门基金
                if searchMode == .funds && searchText.isEmpty {
                    fundResults = JapanFundService.popularFunds
                }
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
                prompt: Text(searchMode == .stocks ? "输入代码或名称".localized : "输入基金代码或名称".localized)
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
                    results = []
                    if searchMode == .funds {
                        fundResults = JapanFundService.popularFunds
                    }
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
        .onChange(of: searchText) { _, _ in
            performSearch()
        }
    }

    // MARK: - 搜索类型选择

    @ViewBuilder
    private var searchModeSelector: some View {
        if fundsOnly {
            // つみたて账户只能搜索投信
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AccountType.nisa_tsumitate.color)

                Text("つみたてNISA対象商品".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AccountType.nisa_tsumitate.color.opacity(0.1))
            )
        } else {
            HStack(spacing: 0) {
                ForEach(SearchMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchMode = mode
                            performSearch()
                        }
                    } label: {
                        Text(mode.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(searchMode == mode ? .white : AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                searchMode == mode ?
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AppColors.profit) : nil
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
    }

    // MARK: - 加载状态

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.profit)

            Text("搜索中...".localized)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 股票搜索结果

    @ViewBuilder
    private var stockResultsList: some View {
        if results.isEmpty && !searchText.isEmpty {
            emptyResultsView
        } else if results.isEmpty && searchText.isEmpty {
            searchPromptView
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("搜索结果".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)

                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.symbol) { index, result in
                        stockResultRow(result)

                        if index < results.count - 1 {
                            Divider()
                                .background(AppColors.dividerColor)
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
            }
        }
    }

    private func stockResultRow(_ result: MarketDataService.SearchQuote) -> some View {
        Button {
            let market = detectMarket(from: result)
            onSelect(result.symbol, result.shortname ?? result.longname ?? result.symbol, market)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                // 市场标识
                ZStack {
                    Circle()
                        .fill(detectMarket(from: result).color.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Text(detectMarket(from: result).flag)
                        .font(.system(size: 16))
                }

                // 信息
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(result.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)

                        if let exchange = result.exchDisp {
                            Text(exchange)
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(AppColors.elevatedSurface)
                                )
                        }
                    }

                    if let name = result.shortname ?? result.longname {
                        Text(name)
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                    }

                    if let type = result.typeDisp {
                        Text(type)
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.profit)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 基金搜索结果

    @ViewBuilder
    private var fundResultsList: some View {
        let displayResults = filteredFundResults

        if displayResults.isEmpty && !searchText.isEmpty {
            if filterTsumitateEligible && !fundResults.isEmpty {
                // 有结果但都不是対象商品
                noEligibleFundsView
            } else {
                emptyResultsView
            }
        } else if displayResults.isEmpty && searchText.isEmpty && filterTsumitateEligible {
            // つみたて模式下显示推荐的対象商品
            tsumitateRecommendedFundsView
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    if filterTsumitateEligible {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AccountType.nisa_tsumitate.color)

                        Text("対象商品".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        Image(systemName: searchText.isEmpty ? "star.fill" : "magnifyingglass")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(searchText.isEmpty ? .orange : AppColors.profit)

                        Text(searchText.isEmpty ? "人气基金".localized : "搜索结果".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                VStack(spacing: 0) {
                    ForEach(Array(displayResults.enumerated()), id: \.element.code) { index, fund in
                        fundResultRow(fund)

                        if index < displayResults.count - 1 {
                            Divider()
                                .background(AppColors.dividerColor)
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
            }
        }
    }

    /// 无対象商品结果提示
    private var noEligibleFundsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf")
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
        .padding(.vertical, 60)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    /// つみたて推荐商品列表
    private var tsumitateRecommendedFundsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AccountType.nisa_tsumitate.color)

                Text("推荐対象商品".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(spacing: 0) {
                let eligiblePopular = JapanFundService.popularFunds.filter { $0.isTsumitateEligible }
                ForEach(Array(eligiblePopular.enumerated()), id: \.element.code) { index, fund in
                    fundResultRow(fund)

                    if index < eligiblePopular.count - 1 {
                        Divider()
                            .background(AppColors.dividerColor)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    private func fundResultRow(_ fund: JapanFundService.FundSearchResult) -> some View {
        Button {
            onSelect(fund.code, fund.name, .JP_FUND)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                // 基金图标
                ZStack {
                    Circle()
                        .fill(fund.isTsumitateEligible ? AccountType.nisa_tsumitate.color.opacity(0.15) : Color.purple.opacity(0.15))
                        .frame(width: 36, height: 36)

                    if fund.isTsumitateEligible {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AccountType.nisa_tsumitate.color)
                    } else {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.purple)
                    }
                }

                // 信息
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(fund.code)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppColors.textPrimary)

                        if fund.isTsumitateEligible {
                            Text("対象".localized)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(AccountType.nisa_tsumitate.color)
                                )
                        }

                        if let category = fund.category {
                            Text(category)
                                .font(.system(size: 11))
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.purple.opacity(0.1))
                                )
                        }
                    }

                    Text(fund.name)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)

                    if let company = fund.managementCompany {
                        Text(company)
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.profit)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 空状态

    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.textTertiary)

            Text("未找到相关标的".localized)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.textSecondary)

            Text("请尝试其他关键词".localized)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private var searchPromptView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.textTertiary)

            Text("输入代码或名称开始搜索".localized)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.textSecondary)

            Text("支持美股、日股、港股、A股等".localized)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - 搜索逻辑

    private func performSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    private func search() async {
        if searchMode == .stocks {
            await searchStocks()
        } else {
            await searchFunds()
        }
    }

    private func searchStocks() async {
        guard !searchText.isEmpty else {
            results = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            results = try await MarketDataService.shared.searchSymbol(query: searchText)
        } catch {
            results = []
        }
    }

    private func searchFunds() async {
        if searchText.isEmpty {
            fundResults = JapanFundService.popularFunds
            return
        }

        isSearching = true
        defer { isSearching = false }

        fundResults = await JapanFundService.shared.searchFunds(query: searchText)
    }

    private func detectMarket(from quote: MarketDataService.SearchQuote) -> Market {
        let symbol = quote.symbol
        let exchange = quote.exchange ?? ""

        if symbol.hasSuffix(".T") || exchange.contains("TYO") {
            return .JP
        } else if symbol.hasSuffix(".SS") || symbol.hasSuffix(".SZ") {
            return .CN
        } else if symbol.hasSuffix(".HK") {
            return .HK
        } else if symbol.contains("-USD") || exchange.contains("CCC") {
            return .CRYPTO
        } else if symbol.contains("=F") {
            return .COMMODITY
        } else {
            return .US
        }
    }
}

// MARK: - Market Extension

private extension Market {
    var color: Color {
        switch self {
        case .US: return .blue
        case .JP, .JP_FUND: return .red
        case .HK: return .orange
        case .CN: return .yellow
        case .CRYPTO: return .purple
        case .COMMODITY: return .brown
        }
    }
}

#Preview("General Account") {
    SymbolSearchView(accountType: .general) { _, _, _ in }
        .preferredColorScheme(.dark)
}

#Preview("Tsumitate Account") {
    SymbolSearchView(accountType: .nisa_tsumitate) { _, _, _ in }
        .preferredColorScheme(.dark)
}
