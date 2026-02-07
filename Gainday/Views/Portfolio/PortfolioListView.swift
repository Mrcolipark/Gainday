import SwiftUI
import SwiftData

/// 持仓分组模式
enum PortfolioGroupMode: String, CaseIterable {
    case all = "全部"
    case byAccount = "按账户"
    case byMarket = "按市场"

    var displayName: String {
        rawValue.localized
    }
}

/// @deprecated 已被 HomeView 的 PortfolioSectionView 替代，计划移除
struct PortfolioListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]

    @State private var showAddTransaction = false
    @State private var selectedHolding: Holding?
    @State private var searchText = ""
    @State private var quotes: [String: MarketDataService.QuoteData] = [:]
    @State private var isRefreshing = false
    @State private var groupMode: PortfolioGroupMode = .all

    /// 计算 NISA 额度
    private var nisaQuota: NISAOverallQuota {
        NISAQuotaCalculator.calculateOverall(holdings: portfolios.flatMap(\.holdings))
    }

    /// 是否有 NISA 持仓
    private var hasNISAHoldings: Bool {
        portfolios.flatMap(\.holdings).contains { $0.isNISA }
    }

    var body: some View {
        NavigationStack {
            Group {
                if portfolios.isEmpty {
                    emptyState
                } else {
                    portfolioList
                }
            }
            .background(listBackground)
            .navigationTitle("持仓".localized)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.body.weight(.medium))
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                groupModeSelector
            }
            .searchable(text: $searchText, prompt: "搜索持仓".localized)
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView(portfolios: portfolios)
            }
            .sheet(item: $selectedHolding) { holding in
                HoldingDetailView(holding: holding, quote: quotes[holding.symbol])
            }
            .refreshable {
                await refreshQuotes()
            }
            .task {
                await refreshQuotes()
            }
        }
    }

    // MARK: - Background

    private var listBackground: some View {
        AppColors.background
            .ignoresSafeArea()
    }

    // MARK: - 分组选择器

    private var groupModeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PortfolioGroupMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            groupMode = mode
                        }
                    } label: {
                        Text(mode.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(groupMode == mode ? .white : AppColors.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(groupMode == mode ? AppColors.profit : AppColors.cardSurface)
                            )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(AppColors.background)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(Color.blue.opacity(0.05))
                    .frame(width: 100, height: 100)
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue.opacity(0.6))
            }
            VStack(spacing: 8) {
                Text("暂无持仓".localized)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("请先在设置中创建账户，然后添加交易".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    // MARK: - Portfolio List

    private var portfolioList: some View {
        List {
            switch groupMode {
            case .all:
                // 按账户分组（原有逻辑）
                ForEach(portfolios) { portfolio in
                    Section {
                        let filtered = filteredHoldings(for: portfolio)
                        if filtered.isEmpty && !searchText.isEmpty {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                Text("无匹配结果".localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, holding in
                                holdingRow(holding, from: portfolio, index: index)
                            }
                        }
                    } header: {
                        AccountSection(portfolio: portfolio, quotes: quotes)
                    }
                }

            case .byAccount:
                // 按账户类型分组（一般/NISA つみたて/NISA 成長）
                ForEach(accountTypeGroups, id: \.type) { group in
                    Section {
                        ForEach(Array(group.holdings.enumerated()), id: \.element.id) { index, holding in
                            if let portfolio = holding.portfolio {
                                holdingRow(holding, from: portfolio, index: index)
                            }
                        }
                    } header: {
                        accountTypeHeader(group)
                    }
                }

            case .byMarket:
                // 按市场分组
                ForEach(marketGroups, id: \.market) { group in
                    Section {
                        ForEach(Array(group.holdings.enumerated()), id: \.element.id) { index, holding in
                            if let portfolio = holding.portfolio {
                                holdingRow(holding, from: portfolio, index: index)
                            }
                        }
                    } header: {
                        marketHeader(group)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    // MARK: - 持仓行

    private func holdingRow(_ holding: Holding, from portfolio: Portfolio, index: Int) -> some View {
        HoldingRow(
            holding: holding,
            quote: quotes[holding.symbol]
        )
        .staggeredAppearance(index: index)
        .onTapGesture {
            selectedHolding = holding
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteHolding(holding, from: portfolio)
            } label: {
                Label("删除".localized, systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                showAddTransaction = true
            } label: {
                Label("加仓".localized, systemImage: "plus.circle")
            }
            Button {
                selectedHolding = holding
            } label: {
                Label("详情".localized, systemImage: "info.circle")
            }
        }
    }

    // MARK: - 账户类型分组

    private struct AccountTypeGroup {
        let type: AccountType
        let holdings: [Holding]
    }

    private var accountTypeGroups: [AccountTypeGroup] {
        let allHoldings = filteredAllHoldings
        let grouped = Dictionary(grouping: allHoldings) { $0.accountTypeEnum }

        // 排序：一般 -> つみたて -> 成長
        let order: [AccountType] = [.general, .nisa_tsumitate, .nisa_growth]
        return order.compactMap { type in
            guard let holdings = grouped[type], !holdings.isEmpty else { return nil }
            return AccountTypeGroup(type: type, holdings: holdings)
        }
    }

    private func accountTypeHeader(_ group: AccountTypeGroup) -> some View {
        HStack(spacing: 8) {
            Image(systemName: group.type.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(group.type.color)

            Text(group.type.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            if group.type.isNISA {
                NISABadge(accountType: group.type)
            }

            Spacer()

            // NISA 剩余额度
            if group.type.isNISA, let annualLimit = group.type.annualLimit {
                let used = group.type == .nisa_tsumitate
                    ? nisaQuota.tsumitateAnnualUsed
                    : nisaQuota.growthAnnualUsed
                let remaining = annualLimit - used

                Text("剩余额度".localized + ": " + formatManYen(remaining))
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    // MARK: - 市场分组

    private struct MarketGroup {
        let market: Market
        let holdings: [Holding]
    }

    private var marketGroups: [MarketGroup] {
        let allHoldings = filteredAllHoldings
        let grouped = Dictionary(grouping: allHoldings) { $0.marketEnum }

        return Market.allCases.compactMap { market in
            guard let holdings = grouped[market], !holdings.isEmpty else { return nil }
            return MarketGroup(market: market, holdings: holdings)
        }
    }

    private func marketHeader(_ group: MarketGroup) -> some View {
        HStack(spacing: 8) {
            Text(group.market.flag)
                .font(.system(size: 16))

            Text(group.market.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            Text("\(group.holdings.count) " + "持仓".localized)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    // MARK: - 筛选后的全部持仓

    private var filteredAllHoldings: [Holding] {
        let allHoldings = portfolios.flatMap(\.holdings)
        if searchText.isEmpty {
            return allHoldings
        }
        return allHoldings.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.symbol.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func formatManYen(_ value: Double) -> String {
        let manYen = value / 10000
        if manYen >= 100 {
            return String(format: "%.0f万", manYen)
        } else if manYen >= 1 {
            return String(format: "%.1f万", manYen)
        } else {
            return String(format: "%.0f円", value)
        }
    }

    // MARK: - Helpers

    private func filteredHoldings(for portfolio: Portfolio) -> [Holding] {
        if searchText.isEmpty {
            return portfolio.holdings
        }
        return portfolio.holdings.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.symbol.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func deleteHolding(_ holding: Holding, from portfolio: Portfolio) {
        portfolio.holdings.removeAll { $0.id == holding.id }
        modelContext.delete(holding)
    }

    private func refreshQuotes() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let allSymbols = Array(Set(portfolios.flatMap(\.holdings).map(\.symbol)))
        guard !allSymbols.isEmpty else { return }

        do {
            let results = try await MarketDataService.shared.fetchQuotes(symbols: allSymbols)
            var newQuotes: [String: MarketDataService.QuoteData] = [:]
            for q in results {
                newQuotes[q.symbol] = q
            }
            withAnimation {
                quotes = newQuotes
            }
        } catch {
            // Handle error
        }
    }
}

#Preview {
    PortfolioListView()
        .modelContainer(for: Portfolio.self, inMemory: true)
}
