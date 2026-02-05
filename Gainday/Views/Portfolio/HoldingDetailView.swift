import SwiftUI
import Charts

struct HoldingDetailView: View {
    let holding: Holding
    let quote: MarketDataService.QuoteData?

    @Environment(\.colorScheme) private var colorScheme
    @State private var chartData: [PriceCacheData] = []
    @State private var isLoadingChart = false
    @State private var animateContent = false
    @State private var selectedTimeRange: TimeRange = .threeMonths
    @State private var selectedTab = 0

    private var currentPrice: Double {
        quote?.regularMarketPrice ?? 0
    }

    private var pnlColor: Color {
        let unrealized = (currentPrice - holding.averageCost) * holding.totalQuantity
        return unrealized >= 0 ? .green : .red
    }

    private var marketState: MarketState? {
        guard let stateStr = quote?.marketState else { return nil }
        return MarketState(rawValue: stateStr)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Hero: Symbol + Name, large price, change badge, market state
                    heroSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)

                    // 2. Interactive chart with time range selector
                    chartSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 15)

                    // 3. Tabbed sections
                    tabbedSections
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 10)
                }
                .padding()
            }
            .background(detailBackground)
            .navigationTitle(holding.symbol)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                await loadChartData()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animateContent = true
                }
            }
        }
    }

    // MARK: - Background

    private var detailBackground: some View {
        AppColors.background
            .ignoresSafeArea()
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        AccentGlassCard(color: pnlColor) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            // Ticker icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [pnlColor.opacity(0.15), pnlColor.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                Image(systemName: holding.assetTypeEnum.iconName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(pnlColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(holding.symbol)
                                    .font(AppFonts.tickerSymbol)
                                Text(holding.name)
                                    .font(AppFonts.tickerName)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Spacer()
                    if let state = marketState {
                        MarketStateLabel(state: state)
                    }
                }

                // Large price
                Text(currentPrice.currencyFormatted(code: holding.currency))
                    .font(AppFonts.largeAmount)
                    .contentTransition(.numericText())

                // Change badge
                if let change = quote?.regularMarketChange,
                   let changePct = quote?.regularMarketChangePercent {
                    HStack(spacing: 8) {
                        PnLText(change, currencyCode: holding.currency, style: .small)
                        PnLPercentText(changePct, style: .caption)
                    }
                }
            }
        }
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        GlassCard(tint: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                // Time range selector pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach([TimeRange.week, .month, .threeMonths, .sixMonths, .year]) { range in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedTimeRange = range
                                }
                                Task { await loadChartData() }
                            } label: {
                                Text(range.displayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(selectedTimeRange == range ? .white : .secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background {
                                        if selectedTimeRange == range {
                                            Capsule()
                                                .fill(Color.blue)
                                        } else {
                                            Capsule()
                                                .fill(.ultraThinMaterial)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if isLoadingChart {
                    LoadingShimmer(height: 200)
                } else if !chartData.isEmpty {
                    interactiveChart
                        .frame(height: 200)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title2)
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("No chart data")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var interactiveChart: some View {
        let isPositive = (chartData.last?.close ?? 0) >= (chartData.first?.close ?? 0)
        let lineColor: Color = isPositive ? .green : .red

        return Chart(chartData, id: \.date) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Price", point.close)
            )
            .foregroundStyle(lineColor)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.monotone)

            AreaMark(
                x: .value("Date", point.date),
                y: .value("Price", point.close)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [lineColor.opacity(0.2), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(price.formatted(.number.precision(.fractionLength(0))))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Tabbed Sections

    private var tabbedSections: some View {
        VStack(spacing: 12) {
            // Tab picker
            Picker("Section", selection: $selectedTab) {
                Text("Summary").tag(0)
                Text("Position").tag(1)
                Text("Transactions").tag(2)
            }
            .pickerStyle(.segmented)

            switch selectedTab {
            case 0:
                quoteStatsGrid
            case 1:
                positionCard
            case 2:
                transactionCard
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Quote Stats Grid

    private var quoteStatsGrid: some View {
        GlassCard(tint: .indigo) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                    Text("Quote Details")
                        .font(AppFonts.cardTitle)
                }

                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 10) {
                    QuoteStatCell(label: "Open", value: (quote?.regularMarketOpen ?? 0).currencyFormatted(code: holding.currency))
                    QuoteStatCell(label: "Prev Close", value: (quote?.regularMarketPreviousClose ?? 0).currencyFormatted(code: holding.currency))
                    QuoteStatCell(label: "Day High", value: (quote?.regularMarketDayHigh ?? 0).currencyFormatted(code: holding.currency))
                    QuoteStatCell(label: "Day Low", value: (quote?.regularMarketDayLow ?? 0).currencyFormatted(code: holding.currency))
                    QuoteStatCell(label: "Volume", value: (quote?.regularMarketVolume ?? 0).compactFormatted())
                    QuoteStatCell(label: "Market Cap", value: (quote?.marketCap ?? 0).compactFormatted())
                    QuoteStatCell(label: "P/E", value: String(format: "%.2f", quote?.trailingPE ?? 0))
                    QuoteStatCell(label: "52W High", value: (quote?.fiftyTwoWeekHigh ?? 0).currencyFormatted(code: holding.currency))
                    QuoteStatCell(label: "52W Low", value: (quote?.fiftyTwoWeekLow ?? 0).currencyFormatted(code: holding.currency))
                    QuoteStatCell(label: "Div Yield", value: String(format: "%.2f%%", (quote?.dividendYield ?? 0) * 100))
                }
            }
        }
    }

    // MARK: - Position Card

    private var positionCard: some View {
        GlassCard(tint: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "briefcase.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("Position")
                        .font(AppFonts.cardTitle)
                }

                GlassInfoRow(icon: "number", iconColor: .blue, label: "Quantity", value: holding.totalQuantity.formattedQuantity)
                GlassInfoRow(icon: "yensign.circle", iconColor: .orange, label: "Avg Cost", value: holding.averageCost.currencyFormatted(code: holding.currency))
                GlassInfoRow(icon: "banknote", iconColor: .teal, label: "Total Cost", value: holding.totalCost.currencyFormatted(code: holding.currency))
                GlassInfoRow(icon: "chart.bar.fill", iconColor: .indigo, label: "Market Value", value: (currentPrice * holding.totalQuantity).currencyFormatted(code: holding.currency))

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .secondary.opacity(0.15), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)

                let unrealized = (currentPrice - holding.averageCost) * holding.totalQuantity
                let unrealizedPct = holding.averageCost > 0
                    ? ((currentPrice - holding.averageCost) / holding.averageCost) * 100
                    : 0

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: unrealized >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                            .font(.caption)
                            .foregroundStyle(unrealized >= 0 ? .green : .red)
                        Text("Unrealized P&L")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        PnLText(unrealized, currencyCode: holding.currency, style: .small)
                        PnLPercentText(unrealizedPct, style: .caption)
                    }
                }

                if holding.totalDividends > 0 {
                    GlassInfoRow(icon: "gift.fill", iconColor: .orange, label: "Total Dividends", value: holding.totalDividends.currencyFormatted(code: holding.currency))
                }
            }
        }
    }

    // MARK: - Transaction Card

    private var transactionCard: some View {
        GlassCard(tint: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Transactions")
                        .font(AppFonts.cardTitle)
                }

                let sorted = holding.transactions.sorted { $0.date > $1.date }
                if sorted.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("No transactions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, tx in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(tx.transactionType.color.opacity(0.12))
                                    .frame(width: 30, height: 30)
                                Image(systemName: tx.transactionType.iconName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(tx.transactionType.color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tx.transactionType.displayName)
                                    .font(.subheadline.weight(.medium))
                                Text(tx.date.shortDateString)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("×\(tx.quantity.formattedQuantity) @ \(tx.price.currencyFormatted(code: tx.currency))")
                                    .font(.caption.monospacedDigit())
                                if !tx.note.isEmpty {
                                    Text(tx.note)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .staggeredAppearance(index: index)

                        if index < sorted.count - 1 {
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data

    private func loadChartData() async {
        isLoadingChart = true
        defer { isLoadingChart = false }

        let range: String
        switch selectedTimeRange {
        case .week: range = "5d"
        case .month: range = "1mo"
        case .threeMonths: range = "3mo"
        case .sixMonths: range = "6mo"
        case .year: range = "1y"
        case .all: range = "max"
        }

        do {
            chartData = try await MarketDataService.shared.fetchChartData(symbol: holding.symbol, range: range)
        } catch {
            // Handle error
        }
    }
}

// MARK: - Quote Stat Cell

private struct QuoteStatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.secondary.opacity(0.06))
        }
    }
}

// MARK: - Glass Info Row

private struct GlassInfoRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(iconColor)
                .frame(width: 16)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .monospacedDigit()
        }
    }
}

#Preview {
    HoldingDetailView(
        holding: Holding(symbol: "AAPL", name: "Apple Inc.", market: Market.US.rawValue),
        quote: nil
    )
}
