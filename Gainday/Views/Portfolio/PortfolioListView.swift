import SwiftUI
import SwiftData

struct PortfolioListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]

    @State private var showAddTransaction = false
    @State private var selectedHolding: Holding?
    @State private var searchText = ""
    @State private var quotes: [String: MarketDataService.QuoteData] = [:]
    @State private var isRefreshing = false

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
            .navigationTitle("持仓")
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
            .searchable(text: $searchText, prompt: "搜索持仓")
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
                Text("暂无持仓")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("请先在设置中创建账户，然后添加交易")
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
            ForEach(portfolios) { portfolio in
                Section {
                    let filtered = filteredHoldings(for: portfolio)
                    if filtered.isEmpty && !searchText.isEmpty {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            Text("无匹配结果")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, holding in
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
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button {
                                    showAddTransaction = true
                                } label: {
                                    Label("加仓", systemImage: "plus.circle")
                                }
                                Button {
                                    selectedHolding = holding
                                } label: {
                                    Label("详情", systemImage: "info.circle")
                                }
                            }
                        }
                    }
                } header: {
                    AccountSection(portfolio: portfolio, quotes: quotes)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
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
