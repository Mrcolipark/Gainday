import Foundation
import SwiftData

actor MarketDataService {
    static let shared = MarketDataService()

    private let session: URLSession
    private let baseChartURL = "https://query1.finance.yahoo.com/v8/finance/chart/"
    private let baseQuoteURL = "https://query1.finance.yahoo.com/v7/finance/quote"
    private let searchURL = "https://query1.finance.yahoo.com/v1/finance/search"

    // Yahoo Finance 认证
    private var crumb: String?
    private var crumbExpiry: Date?
    private let crumbLifetime: TimeInterval = 3600 // 1 小时

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Yahoo Finance Authentication

    /// 获取有效的 crumb（用于 API 认证）
    private func getValidCrumb() async throws -> String {
        // 检查现有 crumb 是否仍然有效
        if let crumb = crumb, let expiry = crumbExpiry, Date() < expiry {
            return crumb
        }

        // 步骤1: 访问 Yahoo Finance 获取 cookie
        let financeURL = URL(string: "https://finance.yahoo.com")!
        let (_, _) = try await session.data(from: financeURL)

        // 步骤2: 获取 crumb
        let crumbURL = URL(string: "https://query1.finance.yahoo.com/v1/test/getcrumb")!
        let (data, response) = try await session.data(from: crumbURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let crumbValue = String(data: data, encoding: .utf8),
              !crumbValue.contains("error") else {
            throw MarketDataError.authenticationFailed
        }

        self.crumb = crumbValue
        self.crumbExpiry = Date().addingTimeInterval(crumbLifetime)
        return crumbValue
    }

    // MARK: - Chart Data (Historical)

    struct ChartResponse: Codable {
        let chart: ChartResult
    }

    struct ChartResult: Codable {
        let result: [ChartData]?
        let error: ChartError?
    }

    struct ChartError: Codable {
        let code: String?
        let description: String?
    }

    struct ChartData: Codable {
        let meta: ChartMeta
        let timestamp: [Int]?
        let indicators: ChartIndicators
    }

    struct ChartMeta: Codable {
        let currency: String?
        let symbol: String?
        let regularMarketPrice: Double?
        let previousClose: Double?
        let chartPreviousClose: Double?
        let regularMarketTime: Int?
        let exchangeTimezoneName: String?

        // Extended hours data (may be nil from chart API)
        let preMarketPrice: Double?
        let preMarketChange: Double?
        let preMarketChangePercent: Double?
        let postMarketPrice: Double?
        let postMarketChange: Double?
        let postMarketChangePercent: Double?

        // Additional market data
        let regularMarketOpen: Double?
        let regularMarketDayHigh: Double?
        let regularMarketDayLow: Double?
        let regularMarketVolume: Double?
        let fiftyTwoWeekHigh: Double?
        let fiftyTwoWeekLow: Double?

        // Trading periods for calculating market state
        let currentTradingPeriod: TradingPeriods?

        struct TradingPeriods: Codable {
            let pre: TradingPeriod?
            let regular: TradingPeriod?
            let post: TradingPeriod?
        }

        struct TradingPeriod: Codable {
            let start: Int?
            let end: Int?
            let timezone: String?
        }

        /// 根据交易时段计算当前市场状态
        func calculateMarketState() -> String? {
            guard let periods = currentTradingPeriod else { return nil }
            let now = Int(Date().timeIntervalSince1970)

            // 检查是否在盘前
            if let pre = periods.pre, let start = pre.start, let end = pre.end {
                if now >= start && now < end {
                    return "PRE"
                }
            }

            // 检查是否在交易时段
            if let regular = periods.regular, let start = regular.start, let end = regular.end {
                if now >= start && now < end {
                    return "REGULAR"
                }
            }

            // 检查是否在盘后
            if let post = periods.post, let start = post.start, let end = post.end {
                if now >= start && now < end {
                    return "POST"
                }
            }

            return "CLOSED"
        }
    }

    struct ChartIndicators: Codable {
        let quote: [ChartQuote]
    }

    struct ChartQuote: Codable {
        let open: [Double?]
        let high: [Double?]
        let low: [Double?]
        let close: [Double?]
    }

    func fetchChartData(symbol: String, interval: String = "1d", range: String = "3mo") async throws -> [PriceCacheData] {
        let urlString = "\(baseChartURL)\(symbol)?interval=\(interval)&range=\(range)"
        guard let url = URL(string: urlString) else {
            throw MarketDataError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MarketDataError.httpError
        }

        let chartResponse = try JSONDecoder().decode(ChartResponse.self, from: data)
        guard let result = chartResponse.chart.result?.first,
              let timestamps = result.timestamp,
              let quote = result.indicators.quote.first else {
            throw MarketDataError.noData
        }

        let currency = result.meta.currency ?? "USD"
        var prices: [PriceCacheData] = []

        for i in 0..<timestamps.count {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamps[i]))
            let priceData = PriceCacheData(
                symbol: symbol,
                date: date,
                open: quote.open[i] ?? 0,
                high: quote.high[i] ?? 0,
                low: quote.low[i] ?? 0,
                close: quote.close[i] ?? 0,
                currency: currency
            )
            prices.append(priceData)
        }

        return prices
    }

    // MARK: - Real-time Quote

    struct QuoteResponse: Codable {
        let quoteResponse: QuoteResult
    }

    struct QuoteResult: Codable {
        let result: [QuoteData]?
        let error: QuoteError?
    }

    struct QuoteError: Codable {
        let code: String?
        let description: String?
    }

    struct QuoteData: Codable, Identifiable {
        var id: String { symbol }
        let symbol: String
        let shortName: String?
        let longName: String?
        let regularMarketPrice: Double?
        let regularMarketChange: Double?
        let regularMarketChangePercent: Double?
        let regularMarketPreviousClose: Double?
        let currency: String?
        let marketState: String?

        // Extended hours
        let preMarketPrice: Double?
        let preMarketChange: Double?
        let preMarketChangePercent: Double?
        let postMarketPrice: Double?
        let postMarketChange: Double?
        let postMarketChangePercent: Double?

        // Additional fields for detail view
        let regularMarketOpen: Double?
        let regularMarketDayHigh: Double?
        let regularMarketDayLow: Double?
        let regularMarketVolume: Double?
        let marketCap: Double?
        let trailingPE: Double?
        let fiftyTwoWeekHigh: Double?
        let fiftyTwoWeekLow: Double?
        let dividendYield: Double?
        let epsTrailingTwelveMonths: Double?
    }

    func fetchQuotes(symbols: [String]) async throws -> [QuoteData] {
        guard !symbols.isEmpty else { return [] }

        // 使用 chart API 获取实时价格（v7 quote API 已被限制访问）
        var results: [QuoteData] = []

        // 并发获取所有股票数据
        await withTaskGroup(of: QuoteData?.self) { group in
            for symbol in symbols {
                group.addTask {
                    do {
                        return try await self.fetchQuoteViaChart(symbol: symbol)
                    } catch {
                        #if DEBUG
                        print("⚠️ Failed to fetch \(symbol): \(error)")
                        #endif
                        return nil
                    }
                }
            }

            for await result in group {
                if let quote = result {
                    results.append(quote)
                }
            }
        }

        return results
    }

    /// 通过 chart API 获取单个股票的实时报价
    private func fetchQuoteViaChart(symbol: String) async throws -> QuoteData {
        // 使用 1 分钟间隔 + includePrePost 获取盘前盘后实时数据
        let urlString = "\(baseChartURL)\(symbol)?interval=1m&range=1d&includePrePost=true&prepost=true"
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString) else {
            throw MarketDataError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MarketDataError.httpError
        }

        let chartResponse = try JSONDecoder().decode(ChartResponse.self, from: data)
        guard let result = chartResponse.chart.result?.first else {
            throw MarketDataError.noData
        }

        let meta = result.meta
        let regularMarketPrice = meta.regularMarketPrice ?? 0
        let previousClose = meta.previousClose ?? meta.chartPreviousClose ?? 0

        // 计算市场状态
        let marketState = meta.calculateMarketState()

        // 从图表数据获取最新价格（包含盘前盘后）
        var latestPrice = regularMarketPrice
        var preMarketPrice: Double?
        var postMarketPrice: Double?
        var preMarketChange: Double?
        var postMarketChange: Double?
        var preMarketChangePercent: Double?
        var postMarketChangePercent: Double?

        // 获取最新的非空价格
        if let quotes = result.indicators.quote.first,
           let latestClose = quotes.close.compactMap({ $0 }).last {
            latestPrice = latestClose

            // 根据市场状态设置盘前/盘后价格
            if marketState == "PRE" || marketState == "PREPRE" {
                preMarketPrice = latestPrice
                if previousClose > 0 {
                    preMarketChange = latestPrice - previousClose
                    preMarketChangePercent = (preMarketChange! / previousClose) * 100
                }
            } else if marketState == "POST" || marketState == "POSTPOST" {
                postMarketPrice = latestPrice
                if regularMarketPrice > 0 {
                    postMarketChange = latestPrice - regularMarketPrice
                    postMarketChangePercent = (postMarketChange! / regularMarketPrice) * 100
                }
            }
        }

        // 日内涨跌（基于收盘价）
        let change = regularMarketPrice - previousClose
        let changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0

        return QuoteData(
            symbol: symbol,
            shortName: nil,
            longName: nil,
            regularMarketPrice: regularMarketPrice,
            regularMarketChange: change,
            regularMarketChangePercent: changePercent,
            regularMarketPreviousClose: previousClose,
            currency: meta.currency,
            marketState: marketState,
            preMarketPrice: preMarketPrice ?? meta.preMarketPrice,
            preMarketChange: preMarketChange ?? meta.preMarketChange,
            preMarketChangePercent: preMarketChangePercent ?? meta.preMarketChangePercent,
            postMarketPrice: postMarketPrice ?? meta.postMarketPrice,
            postMarketChange: postMarketChange ?? meta.postMarketChange,
            postMarketChangePercent: postMarketChangePercent ?? meta.postMarketChangePercent,
            regularMarketOpen: meta.regularMarketOpen,
            regularMarketDayHigh: meta.regularMarketDayHigh,
            regularMarketDayLow: meta.regularMarketDayLow,
            regularMarketVolume: meta.regularMarketVolume,
            marketCap: nil,
            trailingPE: nil,
            fiftyTwoWeekHigh: meta.fiftyTwoWeekHigh,
            fiftyTwoWeekLow: meta.fiftyTwoWeekLow,
            dividendYield: nil,
            epsTrailingTwelveMonths: nil
        )
    }

    func fetchQuote(symbol: String) async throws -> QuoteData {
        let results = try await fetchQuotes(symbols: [symbol])
        guard let quote = results.first else {
            throw MarketDataError.noData
        }
        return quote
    }

    // MARK: - Detailed Quote (with financials: PE, EPS, MarketCap, DividendYield)

    struct QuoteSummaryResponse: Codable {
        let quoteSummary: QuoteSummaryResult
    }

    struct QuoteSummaryResult: Codable {
        let result: [QuoteSummaryData]?
        let error: QuoteSummaryError?
    }

    struct QuoteSummaryError: Codable {
        let code: String?
        let description: String?
    }

    struct QuoteSummaryData: Codable {
        let price: PriceModule?
        let summaryDetail: SummaryDetailModule?
        let defaultKeyStatistics: KeyStatisticsModule?
    }

    struct PriceModule: Codable {
        let symbol: String?
        let shortName: String?
        let longName: String?
        let regularMarketPrice: RawValue?
        let regularMarketChange: RawValue?
        let regularMarketChangePercent: RawValue?
        let regularMarketPreviousClose: RawValue?
        let regularMarketOpen: RawValue?
        let regularMarketDayHigh: RawValue?
        let regularMarketDayLow: RawValue?
        let regularMarketVolume: RawValue?
        let marketCap: RawValue?
        let currency: String?
        let marketState: String?
    }

    struct SummaryDetailModule: Codable {
        let trailingPE: RawValue?
        let forwardPE: RawValue?
        let dividendYield: RawValue?
        let fiftyTwoWeekHigh: RawValue?
        let fiftyTwoWeekLow: RawValue?
    }

    struct KeyStatisticsModule: Codable {
        let trailingEps: RawValue?
        let forwardEps: RawValue?
    }

    struct RawValue: Codable {
        let raw: Double?
        let fmt: String?
    }

    /// 获取详细报价数据（包含市盈率、市值等财务数据）
    func fetchDetailedQuote(symbol: String) async throws -> QuoteData {
        // 获取认证 crumb
        let crumb: String
        do {
            crumb = try await getValidCrumb()
        } catch {
            // 如果获取 crumb 失败，回退到 chart API
            print("[MarketDataService] Failed to get crumb, falling back to chart API")
            return try await fetchQuote(symbol: symbol)
        }

        let modules = "price,summaryDetail,defaultKeyStatistics"
        let urlString = "https://query1.finance.yahoo.com/v10/finance/quoteSummary/\(symbol)?modules=\(modules)&crumb=\(crumb)"
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString) else {
            throw MarketDataError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // 如果 quoteSummary API 失败，清除 crumb 并回退到 chart API
            self.crumb = nil
            self.crumbExpiry = nil
            return try await fetchQuote(symbol: symbol)
        }

        let summaryResponse: QuoteSummaryResponse
        do {
            summaryResponse = try JSONDecoder().decode(QuoteSummaryResponse.self, from: data)
        } catch {
            return try await fetchQuote(symbol: symbol)
        }

        guard let result = summaryResponse.quoteSummary.result?.first else {
            return try await fetchQuote(symbol: symbol)
        }

        let price = result.price
        let summary = result.summaryDetail
        let stats = result.defaultKeyStatistics

        let regularMarketPrice = price?.regularMarketPrice?.raw ?? 0
        let previousClose = price?.regularMarketPreviousClose?.raw ?? 0
        let change = price?.regularMarketChange?.raw ?? (regularMarketPrice - previousClose)
        let changePercent = price?.regularMarketChangePercent?.raw.map { $0 * 100 } ?? (previousClose > 0 ? (change / previousClose) * 100 : 0)

        return QuoteData(
            symbol: symbol,
            shortName: price?.shortName,
            longName: price?.longName,
            regularMarketPrice: regularMarketPrice,
            regularMarketChange: change,
            regularMarketChangePercent: changePercent,
            regularMarketPreviousClose: previousClose,
            currency: price?.currency,
            marketState: price?.marketState,
            preMarketPrice: nil,
            preMarketChange: nil,
            preMarketChangePercent: nil,
            postMarketPrice: nil,
            postMarketChange: nil,
            postMarketChangePercent: nil,
            regularMarketOpen: price?.regularMarketOpen?.raw,
            regularMarketDayHigh: price?.regularMarketDayHigh?.raw,
            regularMarketDayLow: price?.regularMarketDayLow?.raw,
            regularMarketVolume: price?.regularMarketVolume?.raw,
            marketCap: price?.marketCap?.raw,
            trailingPE: summary?.trailingPE?.raw,
            fiftyTwoWeekHigh: summary?.fiftyTwoWeekHigh?.raw,
            fiftyTwoWeekLow: summary?.fiftyTwoWeekLow?.raw,
            dividendYield: summary?.dividendYield?.raw,
            epsTrailingTwelveMonths: stats?.trailingEps?.raw
        )
    }

    // MARK: - Unified Quote Fetching (supports JP funds)

    /// 统一获取报价 - 自动识别市场类型并路由到正确的数据源
    func fetchUnifiedQuote(symbol: String, market: Market) async throws -> QuoteData {
        if market == .JP_FUND {
            // 使用日本投信服务
            let fundQuote = try await JapanFundService.shared.fetchFundQuote(code: symbol)
            return fundQuote.toQuoteData()
        } else {
            // 使用Yahoo Finance
            return try await fetchQuote(symbol: symbol)
        }
    }

    /// 批量获取报价 - 自动路由
    func fetchUnifiedQuotes(holdings: [(symbol: String, market: Market)]) async throws -> [String: QuoteData] {
        var results: [String: QuoteData] = [:]

        // 分组: Yahoo Finance vs Japan Fund
        let yahooSymbols = holdings.filter { $0.market.usesYahooFinance }.map { $0.symbol }
        let fundCodes = holdings.filter { $0.market == .JP_FUND }.map { $0.symbol }

        // Fetch Yahoo Finance quotes (via chart API)
        if !yahooSymbols.isEmpty {
            let yahooQuotes = try await fetchQuotes(symbols: yahooSymbols)
            for quote in yahooQuotes {
                results[quote.symbol] = quote
            }
        }

        // Fetch Japan Fund quotes
        if !fundCodes.isEmpty {
            let fundQuotes = try await JapanFundService.shared.fetchFundQuotes(codes: fundCodes)
            for fundQuote in fundQuotes {
                results[fundQuote.code] = fundQuote.toQuoteData()
            }
        }

        return results
    }

    // MARK: - Market Indices

    static let marketIndexSymbols = [
        "^GSPC",     // S&P 500
        "^DJI",      // Dow Jones
        "^IXIC",     // NASDAQ
        "^N225",     // Nikkei 225
        "^HSI",      // Hang Seng
        "000001.SS", // Shanghai Composite
        "^FTSE",     // FTSE 100
        "^GDAXI"     // DAX
    ]

    func fetchMarketIndices() async throws -> [QuoteData] {
        try await fetchQuotes(symbols: MarketDataService.marketIndexSymbols)
    }

    // MARK: - Sector ETFs

    static let sectorETFSymbols_US = [
        "XLK",   // Technology
        "XLF",   // Financials
        "XLV",   // Health Care
        "XLE",   // Energy
        "XLY",   // Consumer Discretionary
        "XLI",   // Industrials
        "XLB",   // Materials
        "XLRE",  // Real Estate
        "XLC",   // Communication Services
        "XLU",   // Utilities
        "XLP"    // Consumer Staples
    ]

    // 日本 TOPIX-17 行业指数 ETF
    static let sectorETFSymbols_JP = [
        "1615.T",  // TOPIX Banks
        "1617.T",  // TOPIX Foods
        "1618.T",  // TOPIX Energy Resources
        "1619.T",  // TOPIX Construction & Materials
        "1620.T",  // TOPIX Raw Materials & Chemicals
        "1621.T",  // TOPIX Pharmaceutical
        "1622.T",  // TOPIX Automobiles
        "1623.T",  // TOPIX Transportation & Logistics
        "1624.T",  // TOPIX Commercial & Wholesale Trade
        "1625.T",  // TOPIX Retail Trade
        "1626.T",  // TOPIX IT & Services
        "1627.T"   // TOPIX Electric Power & Gas
    ]

    // 香港行业 ETF
    static let sectorETFSymbols_HK = [
        "2800.HK",  // Tracker Fund of Hong Kong
        "2828.HK",  // Hang Seng H-Share Index ETF
        "3067.HK",  // iShares Hang Seng TECH ETF
        "3033.HK",  // CSOP Hang Seng TECH Index ETF
        "2823.HK",  // iShares FTSE A50 China Index ETF
        "3188.HK"   // China AMC CSI 300 Index ETF
    ]

    // A股行业 ETF（上交所/深交所）
    static let sectorETFSymbols_CN = [
        "512480.SS",  // 半导体ETF
        "512660.SS",  // 军工ETF
        "512800.SS",  // 银行ETF
        "512000.SS",  // 券商ETF
        "512010.SS",  // 医药ETF
        "512880.SS",  // 证券ETF
        "515030.SS",  // 新能源车ETF
        "516160.SS",  // 新能源ETF
        "512200.SS",  // 地产ETF
        "512400.SS",  // 有色ETF
        "512690.SS",  // 酒ETF
        "515790.SS"   // 光伏ETF
    ]

    func fetchSectorETFs(market: Any? = nil) async throws -> [QuoteData] {
        // 根据市场类型选择对应的 ETF 列表
        let symbols: [String]

        if let region = market as? MarketsView.MarketRegion {
            switch region {
            case .us:
                symbols = MarketDataService.sectorETFSymbols_US
            case .jp:
                symbols = MarketDataService.sectorETFSymbols_JP
            case .hk:
                symbols = MarketDataService.sectorETFSymbols_HK
            case .cn:
                symbols = MarketDataService.sectorETFSymbols_CN
            }
        } else {
            symbols = MarketDataService.sectorETFSymbols_US
        }

        return try await fetchQuotes(symbols: symbols)
    }

    // MARK: - Market Movers (Real-time rankings)

    // A股 - 沪深300成分股样本（备用）
    static let marketMoverSymbols_CN = [
        "600519.SS", "601318.SS", "600036.SS", "000858.SZ", "600276.SS",
        "601166.SS", "000333.SZ", "600900.SS", "601288.SS", "600030.SS",
        "000001.SZ", "600000.SS", "601398.SS", "600887.SS", "000568.SZ",
        "601888.SS", "600309.SS", "002415.SZ", "600690.SS", "601012.SS",
        "002304.SZ", "600585.SS", "000725.SZ", "601899.SS", "600438.SS"
    ]

    // 港股 - 恒生指数成分股样本（备用）
    static let marketMoverSymbols_HK = [
        "0700.HK", "9988.HK", "0941.HK", "1299.HK", "2318.HK",
        "0005.HK", "3690.HK", "1810.HK", "0388.HK", "0883.HK",
        "0016.HK", "0001.HK", "0027.HK", "2628.HK", "1398.HK",
        "0011.HK", "0939.HK", "0066.HK", "0688.HK", "1928.HK",
        "0762.HK", "0003.HK", "0012.HK", "2007.HK", "0857.HK"
    ]

    // 日股 - 日经225成分股样本（备用）
    static let marketMoverSymbols_JP = [
        "7203.T", "6758.T", "9984.T", "8306.T", "6861.T",
        "7267.T", "9432.T", "6501.T", "7974.T", "4063.T",
        "8035.T", "6902.T", "7751.T", "4502.T", "6098.T",
        "8766.T", "7741.T", "9433.T", "6367.T", "4503.T",
        "8001.T", "3382.T", "6954.T", "4661.T", "6981.T"
    ]

    // Yahoo Finance Screener 响应结构
    struct ScreenerResponse: Codable {
        let finance: ScreenerFinance
    }

    struct ScreenerFinance: Codable {
        let result: [ScreenerResult]?
        let error: ScreenerError?
    }

    struct ScreenerError: Codable {
        let code: String?
        let description: String?
    }

    struct ScreenerResult: Codable {
        let quotes: [ScreenerQuote]?
    }

    struct ScreenerQuote: Codable {
        let symbol: String
        let shortName: String?
        let longName: String?
        let regularMarketPrice: FormattedValue?
        let regularMarketChange: FormattedValue?
        let regularMarketChangePercent: FormattedValue?
        let regularMarketVolume: FormattedValue?
        let marketCap: FormattedValue?
        let trailingPE: FormattedValue?
        let fiftyTwoWeekHigh: FormattedValue?
        let fiftyTwoWeekLow: FormattedValue?
        let dividendYield: FormattedValue?
        let epsTrailingTwelveMonths: FormattedValue?
    }

    struct FormattedValue: Codable {
        let raw: Double?
        let fmt: String?
    }

    /// 获取美股真实涨跌幅排行榜
    func fetchUSMarketMovers(type: String = "gainers") async throws -> [QuoteData] {
        let scrId: String
        switch type {
        case "gainers": scrId = "day_gainers"
        case "losers": scrId = "day_losers"
        case "actives": scrId = "most_actives"
        default: scrId = "day_gainers"
        }

        let urlString = "https://query1.finance.yahoo.com/v1/finance/screener/predefined/saved?formatted=true&lang=en-US&region=US&scrIds=\(scrId)&count=30"
        guard let url = URL(string: urlString) else {
            throw MarketDataError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MarketDataError.httpError
        }

        let screenerResponse = try JSONDecoder().decode(ScreenerResponse.self, from: data)
        guard let quotes = screenerResponse.finance.result?.first?.quotes else {
            throw MarketDataError.noData
        }

        // 转换为 QuoteData
        return quotes.map { sq in
            QuoteData(
                symbol: sq.symbol,
                shortName: sq.shortName,
                longName: sq.longName,
                regularMarketPrice: sq.regularMarketPrice?.raw,
                regularMarketChange: sq.regularMarketChange?.raw,
                regularMarketChangePercent: sq.regularMarketChangePercent?.raw,
                regularMarketPreviousClose: nil,
                currency: "USD",
                marketState: nil,
                preMarketPrice: nil,
                preMarketChange: nil,
                preMarketChangePercent: nil,
                postMarketPrice: nil,
                postMarketChange: nil,
                postMarketChangePercent: nil,
                regularMarketOpen: nil,
                regularMarketDayHigh: nil,
                regularMarketDayLow: nil,
                regularMarketVolume: sq.regularMarketVolume?.raw,
                marketCap: sq.marketCap?.raw,
                trailingPE: sq.trailingPE?.raw,
                fiftyTwoWeekHigh: sq.fiftyTwoWeekHigh?.raw,
                fiftyTwoWeekLow: sq.fiftyTwoWeekLow?.raw,
                dividendYield: sq.dividendYield?.raw,
                epsTrailingTwelveMonths: sq.epsTrailingTwelveMonths?.raw
            )
        }
    }

    /// 获取港股真实涨跌幅排行榜
    func fetchHKMarketMovers(type: String = "gainers") async throws -> [QuoteData] {
        let scrId: String
        switch type {
        case "gainers": scrId = "day_gainers_hk"
        case "losers": scrId = "day_losers_hk"
        case "actives": scrId = "most_actives_hk"
        default: scrId = "day_gainers_hk"
        }

        let urlString = "https://query1.finance.yahoo.com/v1/finance/screener/predefined/saved?formatted=true&lang=en-US&region=US&scrIds=\(scrId)&count=30"
        guard let url = URL(string: urlString) else {
            throw MarketDataError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MarketDataError.httpError
        }

        let screenerResponse = try JSONDecoder().decode(ScreenerResponse.self, from: data)
        guard let quotes = screenerResponse.finance.result?.first?.quotes else {
            throw MarketDataError.noData
        }

        // 转换为 QuoteData
        return quotes.map { sq in
            QuoteData(
                symbol: sq.symbol,
                shortName: sq.shortName,
                longName: sq.longName,
                regularMarketPrice: sq.regularMarketPrice?.raw,
                regularMarketChange: sq.regularMarketChange?.raw,
                regularMarketChangePercent: sq.regularMarketChangePercent?.raw,
                regularMarketPreviousClose: nil,
                currency: "HKD",
                marketState: nil,
                preMarketPrice: nil,
                preMarketChange: nil,
                preMarketChangePercent: nil,
                postMarketPrice: nil,
                postMarketChange: nil,
                postMarketChangePercent: nil,
                regularMarketOpen: nil,
                regularMarketDayHigh: nil,
                regularMarketDayLow: nil,
                regularMarketVolume: sq.regularMarketVolume?.raw,
                marketCap: sq.marketCap?.raw,
                trailingPE: sq.trailingPE?.raw,
                fiftyTwoWeekHigh: sq.fiftyTwoWeekHigh?.raw,
                fiftyTwoWeekLow: sq.fiftyTwoWeekLow?.raw,
                dividendYield: sq.dividendYield?.raw,
                epsTrailingTwelveMonths: sq.epsTrailingTwelveMonths?.raw
            )
        }
    }

    // MARK: - A股真实涨跌幅排行榜 (东方财富 API)

    struct EastMoneyResponse: Codable {
        let rc: Int
        let rt: Int
        let data: EastMoneyData?
    }

    struct EastMoneyData: Codable {
        let total: Int
        let diff: [EastMoneyStock]
    }

    struct EastMoneyStock: Codable {
        let f2: Double?   // 最新价
        let f3: Double?   // 涨跌幅 (%)
        let f4: Double?   // 涨跌额
        let f5: Double?   // 成交量 (手)
        let f6: Double?   // 成交额
        let f7: Double?   // 振幅
        let f12: String   // 代码
        let f14: String   // 名称
        let f15: Double?  // 最高
        let f16: Double?  // 最低
        let f17: Double?  // 开盘
        let f18: Double?  // 昨收
    }

    /// 获取A股真实涨跌幅排行榜 (东方财富 API)
    func fetchCNMarketMovers(type: String = "gainers") async throws -> [QuoteData] {
        // 排序字段: f3=涨跌幅, f5=成交量, f6=成交额
        // po: 1=降序, 0=升序
        let sortField: String
        let sortOrder: String

        switch type {
        case "gainers":
            sortField = "f3"  // 涨跌幅
            sortOrder = "1"   // 降序
        case "losers":
            sortField = "f3"  // 涨跌幅
            sortOrder = "0"   // 升序
        case "actives":
            sortField = "f6"  // 成交额
            sortOrder = "1"   // 降序
        default:
            sortField = "f3"
            sortOrder = "1"
        }

        // fs: 市场筛选 - m:0+t:6,m:0+t:80 = 深市A股, m:1+t:2,m:1+t:23 = 沪市A股
        let urlString = "https://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=30&po=\(sortOrder)&np=1&fltt=2&invt=2&fid=\(sortField)&fs=m:0+t:6,m:0+t:80,m:1+t:2,m:1+t:23&fields=f2,f3,f4,f5,f6,f7,f12,f14,f15,f16,f17,f18"

        guard let url = URL(string: urlString) else {
            throw MarketDataError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MarketDataError.httpError
        }

        let emResponse = try JSONDecoder().decode(EastMoneyResponse.self, from: data)
        guard let emData = emResponse.data else {
            throw MarketDataError.noData
        }

        // 转换为 QuoteData
        return emData.diff.compactMap { stock in
            // 生成 Yahoo Finance 兼容的 symbol
            let code = stock.f12
            let yahooSymbol: String
            if code.hasPrefix("6") {
                yahooSymbol = "\(code).SS"  // 上交所
            } else {
                yahooSymbol = "\(code).SZ"  // 深交所
            }

            guard let price = stock.f2, price > 0 else { return nil }

            return QuoteData(
                symbol: yahooSymbol,
                shortName: stock.f14,
                longName: stock.f14,
                regularMarketPrice: price,
                regularMarketChange: stock.f4,
                regularMarketChangePercent: stock.f3,
                regularMarketPreviousClose: stock.f18,
                currency: "CNY",
                marketState: nil,
                preMarketPrice: nil,
                preMarketChange: nil,
                preMarketChangePercent: nil,
                postMarketPrice: nil,
                postMarketChange: nil,
                postMarketChangePercent: nil,
                regularMarketOpen: stock.f17,
                regularMarketDayHigh: stock.f15,
                regularMarketDayLow: stock.f16,
                regularMarketVolume: stock.f5.map { $0 * 100 },  // 手 -> 股
                marketCap: nil,
                trailingPE: nil,
                fiftyTwoWeekHigh: nil,
                fiftyTwoWeekLow: nil,
                dividendYield: nil,
                epsTrailingTwelveMonths: nil
            )
        }
    }

    // MARK: - 日股真实涨跌幅排行榜 (TradingView Scanner API)

    struct TradingViewScanResponse: Codable {
        let totalCount: Int
        let data: [TradingViewScanResult]
    }

    struct TradingViewScanResult: Codable {
        let s: String      // symbol (format: "TSE:7203")
        let d: [ScanValue] // data: [name/code, close, change%, change_abs, volume]
    }

    // TradingView returns mixed types in array, need custom decoder
    enum ScanValue: Codable {
        case string(String)
        case double(Double)
        case int(Int)
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else if let str = try? container.decode(String.self) {
                self = .string(str)
            } else if let dbl = try? container.decode(Double.self) {
                self = .double(dbl)
            } else if let int = try? container.decode(Int.self) {
                self = .int(int)
            } else {
                self = .null
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let s): try container.encode(s)
            case .double(let d): try container.encode(d)
            case .int(let i): try container.encode(i)
            case .null: try container.encodeNil()
            }
        }

        var stringValue: String? {
            if case .string(let s) = self { return s }
            return nil
        }

        var doubleValue: Double? {
            switch self {
            case .double(let d): return d
            case .int(let i): return Double(i)
            default: return nil
            }
        }
    }

    /// 获取日股真实涨跌幅排行榜 (TradingView Scanner API)
    func fetchJPMarketMovers(type: String = "gainers") async throws -> [QuoteData] {
        let sortBy: String
        let sortOrder: String

        switch type {
        case "gainers":
            sortBy = "change"
            sortOrder = "desc"
        case "losers":
            sortBy = "change"
            sortOrder = "asc"
        case "actives":
            sortBy = "volume"
            sortOrder = "desc"
        default:
            sortBy = "change"
            sortOrder = "desc"
        }

        let urlString = "https://scanner.tradingview.com/japan/scan"
        guard let url = URL(string: urlString) else {
            throw MarketDataError.invalidURL
        }

        // 请求 description 字段获取公司名称
        let requestBody: [String: Any] = [
            "filter": [
                ["left": "change", "operation": "greater", "right": -100]
            ],
            "options": ["lang": "en"],
            "markets": ["japan"],
            "symbols": [
                "query": ["types": []],
                "tickers": []
            ],
            "columns": ["description", "close", "change", "change_abs", "volume"],
            "sort": [
                "sortBy": sortBy,
                "sortOrder": sortOrder
            ],
            "range": [0, 30]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MarketDataError.httpError
        }

        let tvResponse = try JSONDecoder().decode(TradingViewScanResponse.self, from: data)

        // Convert to QuoteData
        // Filter only TSE (Tokyo Stock Exchange) stocks
        return tvResponse.data.compactMap { result in
            guard result.s.hasPrefix("TSE:") else { return nil }
            let code = String(result.s.dropFirst(4))  // Remove "TSE:" prefix
            let yahooSymbol = "\(code).T"

            guard result.d.count >= 5 else { return nil }

            let description = result.d[0].stringValue ?? code
            let close = result.d[1].doubleValue ?? 0
            let changePercent = result.d[2].doubleValue ?? 0
            let changeAbs = result.d[3].doubleValue ?? 0
            let volume = result.d[4].doubleValue ?? 0

            guard close > 0 else { return nil }

            return QuoteData(
                symbol: yahooSymbol,
                shortName: description,
                longName: description,
                regularMarketPrice: close,
                regularMarketChange: changeAbs,
                regularMarketChangePercent: changePercent,
                regularMarketPreviousClose: close - changeAbs,
                currency: "JPY",
                marketState: nil,
                preMarketPrice: nil,
                preMarketChange: nil,
                preMarketChangePercent: nil,
                postMarketPrice: nil,
                postMarketChange: nil,
                postMarketChangePercent: nil,
                regularMarketOpen: nil,
                regularMarketDayHigh: nil,
                regularMarketDayLow: nil,
                regularMarketVolume: volume,
                marketCap: nil,
                trailingPE: nil,
                fiftyTwoWeekHigh: nil,
                fiftyTwoWeekLow: nil,
                dividendYield: nil,
                epsTrailingTwelveMonths: nil
            )
        }
    }

    /// 获取市场热门股票
    /// - Parameters:
    ///   - market: 市场名称 ("美股", "A股", "港股", "日股")
    ///   - type: 排行类型 ("gainers", "losers", "actives")
    func fetchMarketMovers(market: String = "美股", type: String = "gainers") async throws -> [QuoteData] {
        switch market {
        case "美股":
            // 美股使用 Yahoo Finance 真实涨跌幅排行榜 API
            return try await fetchUSMarketMovers(type: type)
        case "港股":
            // 港股使用 Yahoo Finance 真实涨跌幅排行榜 API
            return try await fetchHKMarketMovers(type: type)
        case "A股":
            // A股使用东方财富真实涨跌幅排行榜 API
            return try await fetchCNMarketMovers(type: type)
        case "日股":
            // 日股获取日经225成分股数据，本地排序
            return try await fetchJPMarketMovers(type: type)
        default:
            return try await fetchUSMarketMovers(type: type)
        }
    }

    // MARK: - Symbol Search

    struct SearchResponse: Codable {
        let quotes: [SearchQuote]?
    }

    struct SearchQuote: Codable {
        let symbol: String
        let shortname: String?
        let longname: String?
        let exchDisp: String?
        let typeDisp: String?
        let exchange: String?
    }

    func searchSymbol(query: String) async throws -> [SearchQuote] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(searchURL)?q=\(encoded)&quotesCount=15&newsCount=0"
        guard let url = URL(string: urlString) else {
            throw MarketDataError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MarketDataError.httpError
        }

        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        return searchResponse.quotes ?? []
    }

    // MARK: - Trending Stocks

    private let trendingURL = "https://query1.finance.yahoo.com/v1/finance/trending"

    struct TrendingResponse: Codable {
        let finance: TrendingFinance
    }

    struct TrendingFinance: Codable {
        let result: [TrendingResult]?
        let error: TrendingError?
    }

    struct TrendingError: Codable {
        let code: String?
        let description: String?
    }

    struct TrendingResult: Codable {
        let quotes: [TrendingQuote]?
        let count: Int?
    }

    struct TrendingQuote: Codable {
        let symbol: String
    }

    /// 获取热门股票 - 支持多个地区
    func fetchTrendingSymbols(regions: [String] = ["US", "JP", "HK"]) async throws -> [TrendingStock] {
        var allTrending: [TrendingStock] = []

        await withTaskGroup(of: [TrendingStock].self) { group in
            for region in regions {
                group.addTask {
                    do {
                        return try await self.fetchTrendingForRegion(region: region)
                    } catch {
                        #if DEBUG
                        print("⚠️ Failed to fetch trending for \(region): \(error)")
                        #endif
                        return []
                    }
                }
            }

            for await result in group {
                allTrending.append(contentsOf: result)
            }
        }

        return allTrending
    }

    private func fetchTrendingForRegion(region: String) async throws -> [TrendingStock] {
        let urlString = "\(trendingURL)/\(region)?count=10"
        guard let url = URL(string: urlString) else {
            throw MarketDataError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MarketDataError.httpError
        }

        let trendingResponse = try JSONDecoder().decode(TrendingResponse.self, from: data)
        guard let result = trendingResponse.finance.result?.first,
              let quotes = result.quotes else {
            return []
        }

        // 获取这些股票的详细信息
        let symbols = quotes.map { $0.symbol }
        let detailedQuotes = try await fetchQuotes(symbols: symbols)

        return detailedQuotes.compactMap { quote in
            TrendingStock(
                symbol: quote.symbol,
                name: quote.longName ?? quote.shortName ?? quote.symbol,
                price: quote.regularMarketPrice ?? 0,
                change: quote.regularMarketChange ?? 0,
                changePercent: quote.regularMarketChangePercent ?? 0,
                region: region
            )
        }
    }

    struct TrendingStock {
        let symbol: String
        let name: String
        let price: Double
        let change: Double
        let changePercent: Double
        let region: String

        var market: Market {
            if symbol.hasSuffix(".T") { return .JP }
            if symbol.hasSuffix(".HK") { return .HK }
            if symbol.hasSuffix(".SS") || symbol.hasSuffix(".SZ") { return .CN }
            return .US
        }
    }
}

// MARK: - Data Transfer Object

struct PriceCacheData {
    let symbol: String
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let currency: String
    var preMarketPrice: Double?
    var postMarketPrice: Double?
    var marketState: String?
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Errors

enum MarketDataError: LocalizedError {
    case invalidURL
    case httpError
    case noData
    case decodingError
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:    return "Invalid URL"
        case .httpError:     return "Network error"
        case .noData:        return "No data available"
        case .authenticationFailed: return "Authentication failed"
        case .decodingError: return "Data parsing error"
        }
    }
}
