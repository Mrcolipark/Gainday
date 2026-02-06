import Foundation

actor CurrencyService {
    static let shared = CurrencyService()

    private var rateCache: [String: Double] = [:]
    private var lastFetchDate: Date?
    private var historicalRatesCache: [String: [Date: Double]] = [:]

    private init() {}

    // Yahoo Finance currency pair symbols
    private func currencyPairSymbol(from: String, to: String) -> String {
        "\(from)\(to)=X"
    }

    func getRate(from: String, to: String) async throws -> Double {
        if from == to { return 1.0 }

        let cacheKey = "\(from)\(to)"
        if let cached = rateCache[cacheKey],
           let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < 3600 {
            return cached
        }

        let symbol = currencyPairSymbol(from: from, to: to)
        let quote = try await MarketDataService.shared.fetchQuote(symbol: symbol)
        let rate = quote.regularMarketPrice ?? 1.0

        rateCache[cacheKey] = rate
        lastFetchDate = Date()

        return rate
    }

    /// 获取历史汇率（指定日期）
    func getHistoricalRate(from: String, to: String, date: Date) async -> Double {
        if from == to { return 1.0 }

        let cacheKey = "\(from)\(to)"

        // 检查缓存
        if let cachedRates = historicalRatesCache[cacheKey],
           let rate = cachedRates[date.startOfDay] {
            return rate
        }

        // 如果没有缓存，尝试从已加载的历史数据中查找最近的日期
        if let cachedRates = historicalRatesCache[cacheKey] {
            // 查找最近的可用汇率（向前回溯5天）
            var lookbackDate = date.startOfDay
            for _ in 0..<5 {
                if let rate = cachedRates[lookbackDate] {
                    return rate
                }
                lookbackDate = Calendar.current.date(byAdding: .day, value: -1, to: lookbackDate) ?? lookbackDate
            }
        }

        // 返回默认值1.0（调用方应该先加载历史汇率）
        return 1.0
    }

    /// 批量加载历史汇率（1年数据）
    func loadHistoricalRates(from: String, to: String) async -> [Date: Double] {
        if from == to {
            return [:]
        }

        let cacheKey = "\(from)\(to)"

        // 已缓存则直接返回
        if let cached = historicalRatesCache[cacheKey], !cached.isEmpty {
            return cached
        }

        let symbol = currencyPairSymbol(from: from, to: to)

        do {
            let chartData = try await MarketDataService.shared.fetchChartData(
                symbol: symbol,
                interval: "1d",
                range: "1y"
            )

            var rates: [Date: Double] = [:]
            for data in chartData {
                rates[data.date.startOfDay] = data.close
            }

            historicalRatesCache[cacheKey] = rates
            print("[Currency] Loaded \(rates.count) historical rates for \(cacheKey)")
            return rates
        } catch {
            print("[Currency] Failed to load historical rates for \(cacheKey): \(error)")
            return [:]
        }
    }

    /// 批量加载多个货币对的历史汇率
    func loadAllHistoricalRates(currencies: Set<String>) async -> [String: [Date: Double]] {
        var allRates: [String: [Date: Double]] = [:]

        for fromCurrency in currencies {
            for toCurrency in currencies where fromCurrency != toCurrency {
                let key = "\(fromCurrency)\(toCurrency)"
                if allRates[key] == nil {
                    let rates = await loadHistoricalRates(from: fromCurrency, to: toCurrency)
                    if !rates.isEmpty {
                        allRates[key] = rates
                    }
                }
            }
        }

        return allRates
    }

    func convert(amount: Double, from: String, to: String) async throws -> Double {
        let rate = try await getRate(from: from, to: to)
        return amount * rate
    }

    func refreshRates(currencies: [String], baseCurrency: String) async {
        for currency in currencies where currency != baseCurrency {
            do {
                _ = try await getRate(from: currency, to: baseCurrency)
            } catch {
                // Silently skip failed rate fetches
            }
        }
    }

    func getCachedRate(from: String, to: String) -> Double? {
        if from == to { return 1.0 }
        return rateCache["\(from)\(to)"]
    }

    func clearCache() {
        rateCache.removeAll()
        lastFetchDate = nil
    }
}
