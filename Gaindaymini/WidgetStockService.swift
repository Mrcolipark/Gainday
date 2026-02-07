import Foundation
import SwiftData

// MARK: - Widget Stock Service

actor WidgetStockService {
    static let shared = WidgetStockService()

    private let session: URLSession
    private let baseChartURL = "https://query1.finance.yahoo.com/v8/finance/chart/"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Fetch Watchlist Stocks

    func fetchWatchlistStocks() async -> [WatchlistStock] {
        // 1. 从 SwiftData 获取用户持仓
        let holdings = loadHoldingsFromDatabase()

        guard !holdings.isEmpty else {
            return WatchlistStock.placeholders
        }

        // 2. 获取实时价格和走势数据
        var stocks: [WatchlistStock] = []

        await withTaskGroup(of: WatchlistStock?.self) { group in
            for holding in holdings.prefix(6) {
                group.addTask {
                    await self.fetchStockData(
                        symbol: holding.symbol,
                        name: holding.name,
                        currency: holding.currency
                    )
                }
            }

            for await stock in group {
                if let stock = stock {
                    stocks.append(stock)
                }
            }
        }

        // 按市值排序（这里简化为按原顺序）
        return stocks.isEmpty ? WatchlistStock.placeholders : stocks
    }

    // MARK: - Load Holdings from Database

    private func loadHoldingsFromDatabase() -> [(symbol: String, name: String, currency: String)] {
        do {
            let schema = Schema([DailySnapshot.self, Portfolio.self, Holding.self, Transaction.self, PriceCache.self])
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<Holding>()
            let holdings = try context.fetch(descriptor)

            // 过滤有持仓的股票，根据 market 推断 currency
            return holdings
                .filter { $0.totalQuantity > 0 }
                .map { holding in
                    let market = Market(rawValue: holding.market) ?? .JP
                    return (symbol: holding.symbol, name: holding.name, currency: market.currency)
                }
        } catch {
            return []
        }
    }

    // MARK: - Fetch Stock Data from Yahoo Finance

    private func fetchStockData(symbol: String, name: String, currency: String) async -> WatchlistStock? {
        // 获取日内分时数据（1分钟间隔）
        let urlString = "\(baseChartURL)\(symbol)?interval=5m&range=1d"
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString) else {
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let chartResponse = try JSONDecoder().decode(ChartResponse.self, from: data)
            guard let result = chartResponse.chart.result?.first else {
                return nil
            }

            let meta = result.meta
            let currentPrice = meta.regularMarketPrice ?? 0
            let previousClose = meta.previousClose ?? meta.chartPreviousClose ?? currentPrice
            let change = currentPrice - previousClose
            let changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0

            // 提取走势数据（取最后20个点）
            var sparklineData: [Double] = []
            if let quotes = result.indicators.quote.first {
                sparklineData = quotes.close.compactMap { $0 }.suffix(20).map { $0 }
            }

            // 如果没有走势数据，生成模拟数据
            if sparklineData.count < 2 {
                sparklineData = generateSimulatedSparkline(price: currentPrice, changePercent: changePercent)
            }

            return WatchlistStock(
                id: symbol,
                symbol: symbol,
                name: name,
                price: currentPrice,
                change: change,
                changePercent: changePercent,
                currency: meta.currency ?? currency,
                sparklineData: sparklineData
            )
        } catch {
            return nil
        }
    }

    // MARK: - Generate Simulated Sparkline

    private func generateSimulatedSparkline(price: Double, changePercent: Double) -> [Double] {
        var data: [Double] = []
        let startPrice = price / (1 + changePercent / 100)

        for i in 0..<10 {
            let progress = Double(i) / 9.0
            let noise = Double.random(in: -0.002...0.002) * price
            let value = startPrice + (price - startPrice) * progress + noise
            data.append(value)
        }

        return data
    }
}

// MARK: - Yahoo Finance Response Models

private struct ChartResponse: Codable {
    let chart: ChartResult
}

private struct ChartResult: Codable {
    let result: [ChartData]?
    let error: ChartError?
}

private struct ChartError: Codable {
    let code: String?
    let description: String?
}

private struct ChartData: Codable {
    let meta: ChartMeta
    let timestamp: [Int]?
    let indicators: ChartIndicators
}

private struct ChartMeta: Codable {
    let currency: String?
    let symbol: String?
    let regularMarketPrice: Double?
    let previousClose: Double?
    let chartPreviousClose: Double?
}

private struct ChartIndicators: Codable {
    let quote: [ChartQuote]
}

private struct ChartQuote: Codable {
    let open: [Double?]
    let high: [Double?]
    let low: [Double?]
    let close: [Double?]
}
