import Foundation
import SwiftData

actor MarketDataService {
    static let shared = MarketDataService()

    private let session: URLSession
    private let baseChartURL = "https://query1.finance.yahoo.com/v8/finance/chart/"
    private let baseQuoteURL = "https://query1.finance.yahoo.com/v7/finance/quote"
    private let searchURL = "https://query1.finance.yahoo.com/v1/finance/search"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X)"
        ]
        self.session = URLSession(configuration: config)
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

    struct QuoteData: Codable {
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

    var errorDescription: String? {
        switch self {
        case .invalidURL:    return "Invalid URL"
        case .httpError:     return "Network error"
        case .noData:        return "No data available"
        case .decodingError: return "Data parsing error"
        }
    }
}
