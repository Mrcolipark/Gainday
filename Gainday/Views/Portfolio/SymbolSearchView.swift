import SwiftUI

struct SymbolSearchView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (String, String, Market) -> Void

    @State private var searchText = ""
    @State private var results: [MarketDataService.SearchQuote] = []
    @State private var fundResults: [JapanFundService.FundSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var searchMode: SearchMode = .stocks

    enum SearchMode: String, CaseIterable {
        case stocks = "股票/ETF"
        case funds = "日本投信"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search mode picker
                Picker("搜索类型", selection: $searchMode) {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                List {
                    if isSearching {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("搜索中...")
                                .foregroundStyle(.secondary)
                        }
                    } else if searchMode == .stocks {
                        stockResultsList
                    } else {
                        fundResultsList
                    }
                }
            }
            .navigationTitle("搜索标的")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: searchMode == .stocks ? "输入代码或名称" : "输入基金代码或名称")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onChange(of: searchText) {
                performSearch()
            }
            .onChange(of: searchMode) {
                performSearch()
            }
            .task {
                // Load popular funds initially when in fund mode
                if searchMode == .funds && searchText.isEmpty {
                    fundResults = JapanFundService.popularFunds
                }
            }
        }
    }

    // MARK: - Stock Results

    @ViewBuilder
    private var stockResultsList: some View {
        if results.isEmpty && !searchText.isEmpty {
            Text("无结果")
                .foregroundStyle(.secondary)
        } else {
            ForEach(results, id: \.symbol) { result in
                Button {
                    let market = detectMarket(from: result)
                    onSelect(result.symbol, result.shortname ?? result.longname ?? result.symbol, market)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(result.symbol)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if let exchange = result.exchDisp {
                                Text(exchange)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.1), in: Capsule())
                            }
                        }
                        if let name = result.shortname ?? result.longname {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let type = result.typeDisp {
                            Text(type)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Fund Results

    @ViewBuilder
    private var fundResultsList: some View {
        if fundResults.isEmpty && !searchText.isEmpty {
            Text("无结果")
                .foregroundStyle(.secondary)
        } else {
            // Show popular funds header when no search
            if searchText.isEmpty {
                Section {
                    ForEach(fundResults, id: \.code) { fund in
                        fundRow(fund)
                    }
                } header: {
                    Label("人気ファンド", systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            } else {
                ForEach(fundResults, id: \.code) { fund in
                    fundRow(fund)
                }
            }
        }
    }

    private func fundRow(_ fund: JapanFundService.FundSearchResult) -> some View {
        Button {
            onSelect(fund.code, fund.name, .JP_FUND)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(fund.code)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    Spacer()
                    if let category = fund.category {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1), in: Capsule())
                    }
                }
                Text(fund.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let company = fund.managementCompany {
                    Text(company)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Search Logic

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
            // Show popular funds when no search query
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

#Preview {
    SymbolSearchView { _, _, _ in }
}
