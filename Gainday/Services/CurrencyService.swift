import Foundation

actor CurrencyService {
    static let shared = CurrencyService()

    private var rateCache: [String: Double] = [:]
    private var lastFetchDate: Date?

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
