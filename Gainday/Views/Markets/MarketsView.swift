import SwiftUI
import SwiftData

struct MarketsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var indices: [MarketDataService.QuoteData] = []
    @State private var isLoading = false
    @State private var showSearch = false
    @State private var selectedMoverTab = 0
    @State private var animateContent = false

    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]
    @State private var holdingQuotes: [String: MarketDataService.QuoteData] = [:]

    var body: some View {
        AppNavigationWrapper(title: "Markets") {
            ScrollView {
                VStack(spacing: 16) {
                    // Search bar
                    Button {
                        showSearch = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.body)
                                .foregroundStyle(AppColors.textSecondary)
                            Text("Search symbols...")
                                .font(.body)
                                .foregroundStyle(AppColors.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppColors.cardSurface)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .opacity(animateContent ? 1 : 0)

                    // Market indices horizontal carousel
                    indicesCarousel
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 15)

                    // Market status section
                    if !holdingQuotes.isEmpty {
                        GlassCard(tint: .green) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    Text("Market Status")
                                        .font(AppFonts.cardTitle)
                                }
                                MarketStatusBar(quotes: holdingQuotes)
                            }
                        }
                        .padding(.horizontal)
                        .opacity(animateContent ? 1 : 0)
                    }

                    // Market movers
                    moversSection
                        .opacity(animateContent ? 1 : 0)
                }
                .padding(.bottom, 20)
            }
            .background(marketsBackground)
            .sheet(isPresented: $showSearch) {
                SymbolSearchView { symbol, name, market in
                    showSearch = false
                }
            }
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animateContent = true
                }
            }
        }
    }

    // MARK: - Background

    private var marketsBackground: some View {
        AppColors.background
            .ignoresSafeArea()
    }

    // MARK: - Indices Carousel

    private var indicesCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "globe")
                    .foregroundStyle(.blue)
                Text("Global Indices")
                    .font(AppFonts.cardTitle)
            }
            .padding(.horizontal)

            if isLoading && indices.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            LoadingShimmer(height: 110)
                                .frame(width: 170)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(indices.enumerated()), id: \.element.symbol) { index, quote in
                            MarketIndexCard(quote: quote)
                                .staggeredAppearance(index: index)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Movers Section

    private var moversSection: some View {
        GlassCard(tint: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Market Movers")
                        .font(AppFonts.cardTitle)
                }

                Picker("Movers", selection: $selectedMoverTab) {
                    Text("Gainers").tag(0)
                    Text("Losers").tag(1)
                    Text("Most Active").tag(2)
                }
                .pickerStyle(.segmented)

                let allHoldings = portfolios.flatMap(\.holdings)
                if allHoldings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title2)
                            .foregroundStyle(AppColors.textTertiary)
                        Text("Add holdings to see market movers")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    let movers = sortedMovers(holdings: allHoldings)
                    ForEach(Array(movers.prefix(8).enumerated()), id: \.element.0.id) { index, item in
                        HoldingRow(
                            holding: item.0,
                            quote: holdingQuotes[item.0.symbol],
                            displayMode: .basic,
                            showPercent: true
                        )
                        .staggeredAppearance(index: index)

                        if index < min(movers.count, 8) - 1 {
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func sortedMovers(holdings: [Holding]) -> [(Holding, Double)] {
        let sorted = holdings
            .compactMap { holding -> (Holding, Double)? in
                guard let q = holdingQuotes[holding.symbol],
                      let price = q.regularMarketPrice,
                      let prevClose = q.regularMarketPreviousClose,
                      prevClose > 0 else { return nil }
                let pct = (price - prevClose) / prevClose * 100
                return (holding, pct)
            }

        switch selectedMoverTab {
        case 0: // Gainers
            return sorted.sorted { $0.1 > $1.1 }.filter { $0.1 > 0 }
        case 1: // Losers
            return sorted.sorted { $0.1 < $1.1 }.filter { $0.1 < 0 }
        default: // Most Active
            return sorted.sorted { abs($0.1) > abs($1.1) }
        }
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        // 加载市场指数
        do {
            indices = try await MarketDataService.shared.fetchMarketIndices()
        } catch {
            ErrorPresenter.shared.showToast("加载市场指数失败", type: .warning)
        }

        // 加载持仓报价
        let allSymbols = Array(Set(portfolios.flatMap(\.holdings).map(\.symbol)))
        guard !allSymbols.isEmpty else { return }
        do {
            let results = try await MarketDataService.shared.fetchQuotes(symbols: allSymbols)
            var newQuotes: [String: MarketDataService.QuoteData] = [:]
            for q in results { newQuotes[q.symbol] = q }
            holdingQuotes = newQuotes
        } catch {
            ErrorPresenter.shared.showToast("加载持仓行情失败", type: .error)
        }
    }
}

// MARK: - Market Index Card

struct MarketIndexCard: View {
    let quote: MarketDataService.QuoteData

    private var change: Double { quote.regularMarketChange ?? 0 }
    private var changePct: Double { quote.regularMarketChangePercent ?? 0 }
    private var isPositive: Bool { change >= 0 }

    private var indexName: String {
        switch quote.symbol {
        case "^GSPC":     return "S&P 500"
        case "^DJI":      return "Dow Jones"
        case "^IXIC":     return "NASDAQ"
        case "^N225":     return "Nikkei 225"
        case "^HSI":      return "Hang Seng"
        case "000001.SS": return "Shanghai"
        case "^FTSE":     return "FTSE 100"
        case "^GDAXI":    return "DAX"
        default:          return quote.shortName ?? quote.symbol
        }
    }

    private var flag: String {
        switch quote.symbol {
        case "^GSPC", "^DJI", "^IXIC": return "🇺🇸"
        case "^N225":     return "🇯🇵"
        case "^HSI":      return "🇭🇰"
        case "000001.SS": return "🇨🇳"
        case "^FTSE":     return "🇬🇧"
        case "^GDAXI":    return "🇩🇪"
        default:          return "🌐"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(indexName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            Text((quote.regularMarketPrice ?? 0).formatted(.number.precision(.fractionLength(0))))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()

            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                Text(String(format: "%+.2f%%", changePct))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(isPositive ? AppColors.profit : AppColors.loss)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill((isPositive ? AppColors.profit : AppColors.loss).opacity(0.12))
            }
        }
        .padding(14)
        .frame(width: 170)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.cardSurface)
        }
    }
}

#Preview {
    MarketsView()
        .modelContainer(for: [Portfolio.self], inMemory: true)
}
