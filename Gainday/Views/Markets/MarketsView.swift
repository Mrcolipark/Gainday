import SwiftUI
import SwiftData

struct MarketsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var indices: [MarketDataService.QuoteData] = []
    @State private var sectors: [MarketDataService.QuoteData] = []
    @State private var marketMovers: [MarketDataService.QuoteData] = []
    @State private var isLoading = false
    @State private var selectedMoverTab = 0
    @State private var selectedMarket: MarketRegion = .us
    @State private var animateContent = false
    @State private var selectedQuote: MarketDataService.QuoteData?

    // 橙色主题色
    private let accentOrange = Color.orange

    enum MarketRegion: String, CaseIterable {
        case us = "美股"
        case cn = "A股"
        case hk = "港股"
        case jp = "日股"
    }

    var body: some View {
        AppNavigationWrapper(title: "Markets") {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // 品牌标题
                    brandHeader
                        .opacity(animateContent ? 1 : 0)

                    // 全球指数
                    indicesCarousel
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 15)

                    // 板块热力图
                    sectorHeatmap
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 10)

                    // 市场热门
                    moversSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 10)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 30)
            }
            .background(AppColors.background)
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animateContent = true
                }
            }
            .sheet(item: $selectedQuote) { quote in
                MarketQuoteDetailView(quote: quote)
            }
        }
    }

    private func loadSectors() async {
        do {
            let result = try await MarketDataService.shared.fetchSectorETFs(market: selectedMarket)
            if !result.isEmpty {
                await MainActor.run { sectors = result }
            }
        } catch {
            print("[Markets] Failed to load sectors: \(error)")
        }
    }

    private func loadMovers() async {
        // 根据选择的 tab 确定排行类型
        let type: String
        switch selectedMoverTab {
        case 0: type = "gainers"
        case 1: type = "losers"
        case 2: type = "actives"
        default: type = "gainers"
        }

        do {
            let result = try await MarketDataService.shared.fetchMarketMovers(market: selectedMarket.rawValue, type: type)
            if !result.isEmpty {
                await MainActor.run { marketMovers = result }
            }
        } catch {
            print("[Markets] Failed to load movers: \(error)")
        }
    }

    // MARK: - Brand Header

    private var brandHeader: some View {
        HStack {
            Text("GainDay")
                .font(.custom("Georgia-Bold", size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.profit, AppColors.profit.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("盈历")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()

            // 市场状态指示
            MarketStatusPill()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Indices Ticker

    private var indicesCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(accentOrange)
                Text("全球指数")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal)

            if isLoading && indices.isEmpty {
                TickerLoadingView()
            } else if !indices.isEmpty {
                // 自动轮播的交易所风格指数
                AutoScrollingTicker(indices: indices)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sector Heatmap

    private var sectorHeatmap: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(accentOrange)
                Text("板块热力图")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                // 市场选择器
                HStack(spacing: 0) {
                    ForEach(MarketRegion.allCases, id: \.self) { region in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMarket = region
                            }
                            Task {
                                await loadSectors()
                                await loadMovers()
                            }
                        } label: {
                            Text(region.rawValue)
                                .font(.system(size: 11, weight: selectedMarket == region ? .semibold : .medium))
                                .foregroundStyle(selectedMarket == region ? .white : AppColors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(selectedMarket == region ? accentOrange : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppColors.elevatedSurface)
                )
            }
            .padding(.horizontal)

            if isLoading && sectors.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(0..<8, id: \.self) { _ in
                        LoadingShimmer(height: 70)
                    }
                }
                .padding(.horizontal)
            } else if sectors.isEmpty {
                // 无数据提示
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title2)
                        .foregroundStyle(AppColors.textTertiary)
                    Text("暂无\(selectedMarket.rawValue)板块数据")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
                .padding(.horizontal)
            } else {
                SectorHeatmapGrid(sectors: sectors, market: selectedMarket)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Movers Section

    private var moversSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(accentOrange)
                Text("市场热门")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                // 市场选择器（与板块热力图共用 selectedMarket）
                HStack(spacing: 0) {
                    ForEach(MarketRegion.allCases, id: \.self) { region in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMarket = region
                            }
                            Task {
                                await loadSectors()
                                await loadMovers()
                            }
                        } label: {
                            Text(region.rawValue)
                                .font(.system(size: 11, weight: selectedMarket == region ? .semibold : .medium))
                                .foregroundStyle(selectedMarket == region ? .white : AppColors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(selectedMarket == region ? accentOrange : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppColors.elevatedSurface)
                )
            }
            .padding(.horizontal)

            // 涨跌幅/成交量 分段选择器
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    let titles = ["涨幅榜", "跌幅榜", "成交量"]
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMoverTab = index
                        }
                        // 所有市场都需要重新加载排行榜（现在 A股/日股 也使用真实 API）
                        Task { await loadMovers() }
                    } label: {
                        Text(titles[index])
                            .font(.system(size: 13, weight: selectedMoverTab == index ? .semibold : .medium))
                            .foregroundStyle(selectedMoverTab == index ? .white : AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selectedMoverTab == index ? accentOrange : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.elevatedSurface)
            )
            .padding(.horizontal)

            // 热门列表
            VStack(spacing: 0) {
                if isLoading && marketMovers.isEmpty {
                    ForEach(0..<5, id: \.self) { _ in
                        LoadingShimmer(height: 60)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                    }
                } else {
                    let filtered = filteredMovers
                    if filtered.isEmpty {
                        emptyMoversView
                    } else {
                        ForEach(Array(filtered.prefix(10).enumerated()), id: \.element.symbol) { index, quote in
                            Button {
                                selectedQuote = quote
                            } label: {
                                MoverRow(quote: quote, rank: index + 1, showVolume: selectedMoverTab == 2)
                                    .padding(.horizontal)
                            }
                            .buttonStyle(.plain)

                            if index < min(filtered.count, 10) - 1 {
                                Divider()
                                    .padding(.horizontal)
                                    .opacity(0.3)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
    }

    private var filteredMovers: [MarketDataService.QuoteData] {
        // 所有市场现在都使用真实排行榜 API，数据已按正确顺序排序
        return marketMovers
    }

    private var emptyMoversView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundStyle(AppColors.textTertiary)
            Text("暂无数据")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        await withTaskGroup(of: Void.self) { group in
            // 加载市场指数
            group.addTask {
                do {
                    let result = try await MarketDataService.shared.fetchMarketIndices()
                    if !result.isEmpty {
                        await MainActor.run { self.indices = result }
                    }
                } catch {
                    print("[Markets] Failed to load indices: \(error)")
                }
            }

            // 加载板块数据
            group.addTask {
                do {
                    let result = try await MarketDataService.shared.fetchSectorETFs(market: self.selectedMarket)
                    if !result.isEmpty {
                        await MainActor.run { self.sectors = result }
                    }
                } catch {
                    print("[Markets] Failed to load sectors: \(error)")
                }
            }

            // 加载市场热门股票
            group.addTask {
                do {
                    let result = try await MarketDataService.shared.fetchMarketMovers(market: self.selectedMarket.rawValue)
                    if !result.isEmpty {
                        await MainActor.run { self.marketMovers = result }
                    }
                } catch {
                    print("[Markets] Failed to load movers: \(error)")
                }
            }
        }
    }
}

// MARK: - Market Quote Detail View (复用 HoldingDetailView 的布局风格)

struct MarketQuoteDetailView: View {
    let quote: MarketDataService.QuoteData
    @Environment(\.dismiss) private var dismiss
    @State private var chartData: [PriceCacheData] = []
    @State private var isLoadingChart = false
    @State private var selectedTimeRange: TimeRange = .threeMonths
    @State private var fullQuote: MarketDataService.QuoteData?
    @State private var viewId = UUID()

    private var displayQuote: MarketDataService.QuoteData { fullQuote ?? quote }
    private var changePct: Double { displayQuote.regularMarketChangePercent ?? 0 }
    private var isPositive: Bool { changePct >= 0 }
    private var currency: String { displayQuote.currency ?? "USD" }

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle(quote.symbol)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { dismiss() }
                    }
                }
        }
        .id(viewId)
        .task {
            // 并行加载详细报价和图表
            async let quoteTask: () = loadFullQuote()
            async let chartTask: () = loadChartData()
            _ = await (quoteTask, chartTask)
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 头部价格信息
                headerSection

                // 图表
                chartSection

                // 基本数据
                statsSection

                // 更多信息
                moreStatsSection
            }
            .padding()
        }
        .background(AppColors.background)
    }

    private func loadFullQuote() async {
        do {
            // 使用 fetchDetailedQuote 获取完整财务数据
            let detailedQuote = try await MarketDataService.shared.fetchDetailedQuote(symbol: quote.symbol)
            await MainActor.run { fullQuote = detailedQuote }
        } catch {
            print("[MarketQuoteDetailView] Failed to load full quote: \(error)")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(displayQuote.shortName ?? displayQuote.symbol)
                .font(.headline)
                .foregroundStyle(AppColors.textSecondary)

            Text((displayQuote.regularMarketPrice ?? 0).currencyFormatted(code: currency))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 12))
                    Text((displayQuote.regularMarketChange ?? 0).currencyFormatted(code: currency, showSign: true))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                }

                Text(String(format: "(%+.2f%%)", changePct))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(isPositive ? AppColors.profit : AppColors.loss)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((isPositive ? AppColors.profit : AppColors.loss).opacity(0.15))
            )
        }
        .padding(.vertical, 16)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(spacing: 12) {
            // 时间范围选择器
            HStack(spacing: 8) {
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

            // 图表
            if isLoadingChart {
                ProgressView()
                    .frame(height: 180)
            } else if chartData.isEmpty {
                Text("暂无图表数据")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(height: 180)
            } else {
                SimpleLineChart(data: chartData, isPositive: isPositive)
                    .frame(height: 180)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private var statsSection: some View {
        VStack(spacing: 0) {
            statsRow("开盘", (displayQuote.regularMarketOpen ?? 0).currencyFormatted(code: currency))
            Divider().opacity(0.3)
            statsRow("昨收", (displayQuote.regularMarketPreviousClose ?? 0).currencyFormatted(code: currency))
            Divider().opacity(0.3)
            statsRow("最高", (displayQuote.regularMarketDayHigh ?? 0).currencyFormatted(code: currency))
            Divider().opacity(0.3)
            statsRow("最低", (displayQuote.regularMarketDayLow ?? 0).currencyFormatted(code: currency))
            Divider().opacity(0.3)
            statsRow("成交量", (displayQuote.regularMarketVolume ?? 0).volumeFormatted())
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private var moreStatsSection: some View {
        VStack(spacing: 0) {
            statsRow("市值", formatMarketCap(displayQuote.marketCap))
            Divider().opacity(0.3)
            statsRow("市盈率 (TTM)", formatValue(displayQuote.trailingPE))
            Divider().opacity(0.3)
            statsRow("每股收益", formatCurrency(displayQuote.epsTrailingTwelveMonths))
            Divider().opacity(0.3)
            statsRow("股息率", formatPercent(displayQuote.dividendYield))
            Divider().opacity(0.3)
            statsRow("52周最高", formatPrice(displayQuote.fiftyTwoWeekHigh))
            Divider().opacity(0.3)
            statsRow("52周最低", formatPrice(displayQuote.fiftyTwoWeekLow))
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private func formatMarketCap(_ value: Double?) -> String {
        guard let v = value, v > 0 else { return "-" }
        return v.compactFormatted()
    }

    private func formatValue(_ value: Double?) -> String {
        guard let v = value, v > 0 else { return "-" }
        return String(format: "%.2f", v)
    }

    private func formatCurrency(_ value: Double?) -> String {
        guard let v = value else { return "-" }
        return v.currencyFormatted(code: currency)
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let v = value, v > 0 else { return "-" }
        return String(format: "%.2f%%", v * 100)
    }

    private func formatPrice(_ value: Double?) -> String {
        guard let v = value, v > 0 else { return "-" }
        return v.currencyFormatted(code: currency)
    }

    private func statsRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

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
            chartData = try await MarketDataService.shared.fetchChartData(symbol: quote.symbol, range: range)
        } catch {
            print("[MarketQuoteDetailView] Chart load failed: \(error)")
            chartData = []
        }
    }
}

// MARK: - Simple Line Chart with Axis

struct SimpleLineChart: View {
    let data: [PriceCacheData]
    let isPositive: Bool

    private var prices: [Double] { data.map(\.close) }
    private var minPrice: Double { prices.min() ?? 0 }
    private var maxPrice: Double { prices.max() ?? 0 }

    var body: some View {
        if prices.isEmpty || maxPrice <= minPrice {
            Text("暂无数据")
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 4) {
                // Y轴标签
                VStack {
                    Text(formatPrice(maxPrice))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                    Text(formatPrice((maxPrice + minPrice) / 2))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                    Text(formatPrice(minPrice))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .frame(width: 45)

                // 图表
                GeometryReader { geo in
                    let range = maxPrice - minPrice
                    let stepX = geo.size.width / CGFloat(max(1, prices.count - 1))

                    ZStack {
                        // 网格线
                        VStack {
                            ForEach(0..<3, id: \.self) { _ in
                                Divider().opacity(0.2)
                                Spacer()
                            }
                        }

                        // 折线
                        Path { path in
                            for (index, price) in prices.enumerated() {
                                let x = CGFloat(index) * stepX
                                let y = geo.size.height - ((price - minPrice) / range) * geo.size.height

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(isPositive ? AppColors.profit : AppColors.loss, lineWidth: 1.5)
                    }
                }
            }
        }
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 10000 {
            return String(format: "%.0f", price)
        } else if price >= 100 {
            return String(format: "%.1f", price)
        } else {
            return String(format: "%.2f", price)
        }
    }
}

// MARK: - Market Status Pill (多市场状态)

struct MarketStatusPill: View {
    @State private var marketStatuses: [(String, Bool)] = []

    var body: some View {
        HStack(spacing: 6) {
            ForEach(marketStatuses, id: \.0) { market, isOpen in
                HStack(spacing: 3) {
                    Circle()
                        .fill(isOpen ? Color.green : Color.gray.opacity(0.5))
                        .frame(width: 5, height: 5)
                    Text(market)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isOpen ? AppColors.textPrimary : AppColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(AppColors.elevatedSurface)
        )
        .onAppear {
            updateMarketStatus()
        }
    }

    private func updateMarketStatus() {
        let now = Date()
        marketStatuses = [
            ("美", isUSMarketOpen(now)),
            ("中", isCNMarketOpen(now)),
            ("港", isHKMarketOpen(now)),
            ("日", isJPMarketOpen(now))
        ]
    }

    private func isUSMarketOpen(_ now: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let weekday = cal.component(.weekday, from: now)
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let mins = hour * 60 + minute
        return (2...6).contains(weekday) && mins >= 570 && mins < 960 // 9:30-16:00
    }

    private func isCNMarketOpen(_ now: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let weekday = cal.component(.weekday, from: now)
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let mins = hour * 60 + minute
        let morning = mins >= 570 && mins < 690 // 9:30-11:30
        let afternoon = mins >= 780 && mins < 900 // 13:00-15:00
        return (2...6).contains(weekday) && (morning || afternoon)
    }

    private func isHKMarketOpen(_ now: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        let weekday = cal.component(.weekday, from: now)
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let mins = hour * 60 + minute
        let morning = mins >= 570 && mins < 720 // 9:30-12:00
        let afternoon = mins >= 780 && mins < 960 // 13:00-16:00
        return (2...6).contains(weekday) && (morning || afternoon)
    }

    private func isJPMarketOpen(_ now: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let weekday = cal.component(.weekday, from: now)
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let mins = hour * 60 + minute
        let morning = mins >= 540 && mins < 690 // 9:00-11:30
        let afternoon = mins >= 750 && mins < 900 // 12:30-15:00
        return (2...6).contains(weekday) && (morning || afternoon)
    }
}

// MARK: - Ticker Loading View

struct TickerLoadingView: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.elevatedSurface)
                        .frame(width: 60, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.elevatedSurface)
                        .frame(width: 50, height: 16)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.elevatedSurface)
                        .frame(width: 45, height: 12)
                }
                .padding(.horizontal, 12)

                if true {
                    Rectangle()
                        .fill(AppColors.elevatedSurface.opacity(0.5))
                        .frame(width: 1, height: 32)
                }
            }
        }
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
        .padding(.horizontal)
    }
}

// MARK: - Auto-scrolling Ticker

struct AutoScrollingTicker: View {
    let indices: [MarketDataService.QuoteData]

    @State private var offset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0

    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    private var tickerContent: some View {
        HStack(spacing: 12) {
            ForEach(indices, id: \.symbol) { quote in
                TickerIndexItem(quote: quote)
            }
        }
        .padding(.horizontal, 8)
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
            .overlay {
                HStack(spacing: 0) {
                    tickerContent
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        contentWidth = geo.size.width
                                    }
                            }
                        )
                    tickerContent
                }
                .offset(x: -offset)
            }
            .clipped()
            .onReceive(timer) { _ in
                guard contentWidth > 0 else { return }
                offset += 0.5
                if offset >= contentWidth {
                    offset = 0
                }
            }
    }
}

// MARK: - Ticker Index Item (交易所风格)

struct TickerIndexItem: View {
    let quote: MarketDataService.QuoteData

    private var changePct: Double { quote.regularMarketChangePercent ?? 0 }
    private var isPositive: Bool { changePct >= 0 }

    private var indexName: String {
        switch quote.symbol {
        case "^GSPC":     return "S&P"
        case "^DJI":      return "DOW"
        case "^IXIC":     return "NDX"
        case "^N225":     return "N225"
        case "^HSI":      return "HSI"
        case "000001.SS": return "SSE"
        case "^FTSE":     return "FTSE"
        case "^GDAXI":    return "DAX"
        default:          return quote.symbol
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // 指数名称
            Text(indexName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppColors.textTertiary)
                .lineLimit(1)

            // 价格
            Text((quote.regularMarketPrice ?? 0).formatted(.number.precision(.fractionLength(0))))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            // 涨跌幅
            HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 6))
                Text(String(format: "%.1f%%", abs(changePct)))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundStyle(isPositive ? AppColors.profit : AppColors.loss)

            // 分隔线
            Rectangle()
                .fill(AppColors.elevatedSurface.opacity(0.5))
                .frame(width: 1, height: 24)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Sector Heatmap Grid

struct SectorHeatmapGrid: View {
    let sectors: [MarketDataService.QuoteData]
    var market: MarketsView.MarketRegion = .us

    private var sectorNames: [String: String] {
        switch market {
        case .us:
            return [
                "XLK": "科技", "XLF": "金融", "XLV": "医疗", "XLE": "能源",
                "XLY": "消费", "XLI": "工业", "XLB": "材料", "XLRE": "地产",
                "XLC": "通讯", "XLU": "公用", "XLP": "必需品"
            ]
        case .cn:
            return [
                "512480.SS": "半导体", "512660.SS": "军工", "512800.SS": "银行",
                "512000.SS": "券商", "512010.SS": "医药", "512880.SS": "证券",
                "515030.SS": "新能车", "516160.SS": "新能源", "512200.SS": "地产",
                "512400.SS": "有色", "512690.SS": "白酒", "515790.SS": "光伏"
            ]
        case .hk:
            return [
                "2800.HK": "盈富", "2828.HK": "恒中企", "3067.HK": "恒科技",
                "3033.HK": "南方科技", "2823.HK": "A50", "3188.HK": "华夏300"
            ]
        case .jp:
            return [
                "1615.T": "银行", "1617.T": "食品", "1618.T": "能源",
                "1619.T": "建筑", "1620.T": "材料", "1621.T": "医药",
                "1622.T": "汽车", "1623.T": "运输", "1624.T": "商社",
                "1625.T": "零售", "1626.T": "通讯", "1627.T": "电力"
            ]
        }
    }

    private var sortedSectors: [MarketDataService.QuoteData] {
        sectors.sorted { abs($0.regularMarketChangePercent ?? 0) > abs($1.regularMarketChangePercent ?? 0) }
    }

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(sortedSectors, id: \.symbol) { sector in
                SectorCell(
                    name: sectorNames[sector.symbol] ?? sector.shortName ?? sector.symbol,
                    changePercent: sector.regularMarketChangePercent ?? 0
                )
            }
        }
    }
}

struct SectorCell: View {
    let name: String
    let changePercent: Double

    private var isPositive: Bool { changePercent >= 0 }

    private var cellColor: Color {
        let intensity = min(abs(changePercent) / 3.0, 1.0) // 3% 为最大强度
        if changePercent >= 0 {
            return AppColors.profit.opacity(0.15 + intensity * 0.5)
        } else {
            return AppColors.loss.opacity(0.15 + intensity * 0.5)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)

            Text(String(format: "%+.2f%%", changePercent))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(isPositive ? AppColors.profit : AppColors.loss)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cellColor)
        )
    }
}

// MARK: - Mover Row

struct MoverRow: View {
    let quote: MarketDataService.QuoteData
    let rank: Int
    var showVolume: Bool = false

    private var changePct: Double { quote.regularMarketChangePercent ?? 0 }
    private var isPositive: Bool { changePct >= 0 }

    var body: some View {
        HStack(spacing: 12) {
            // 排名
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(rank <= 3 ? Color.orange : AppColors.textTertiary)
                .frame(width: 24)

            // 股票信息
            VStack(alignment: .leading, spacing: 2) {
                Text(quote.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(quote.shortName ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if showVolume {
                // 成交量
                VStack(alignment: .trailing, spacing: 2) {
                    Text((quote.regularMarketVolume ?? 0).volumeFormatted())
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("成交量")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.textTertiary)
                }
            } else {
                // 价格和涨跌
                VStack(alignment: .trailing, spacing: 2) {
                    Text((quote.regularMarketPrice ?? 0).formatted(.number.precision(.fractionLength(2))))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary)

                    HStack(spacing: 2) {
                        Image(systemName: isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 8))
                        Text(String(format: "%+.2f%%", changePct))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(isPositive ? AppColors.profit : AppColors.loss)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Volume Formatter

extension Double {
    func volumeFormatted() -> String {
        if self >= 1_000_000_000 {
            return String(format: "%.1fB", self / 1_000_000_000)
        } else if self >= 1_000_000 {
            return String(format: "%.1fM", self / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", self / 1_000)
        } else {
            return String(format: "%.0f", self)
        }
    }
}

#Preview {
    MarketsView()
        .modelContainer(for: [Portfolio.self], inMemory: true)
}
