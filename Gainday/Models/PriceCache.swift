import Foundation
import SwiftData

@Model
class PriceCache {
    #Unique<PriceCache>([\.symbol, \.date])

    var symbol: String
    var date: Date
    var open: Double
    var high: Double
    var low: Double
    var close: Double
    var currency: String
    var preMarketPrice: Double?
    var postMarketPrice: Double?
    var marketState: String?

    init(
        symbol: String,
        date: Date = Date(),
        open: Double = 0,
        high: Double = 0,
        low: Double = 0,
        close: Double = 0,
        currency: String = "USD",
        preMarketPrice: Double? = nil,
        postMarketPrice: Double? = nil,
        marketState: String? = nil
    ) {
        self.symbol = symbol
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.currency = currency
        self.preMarketPrice = preMarketPrice
        self.postMarketPrice = postMarketPrice
        self.marketState = marketState
    }

    var marketStateEnum: MarketState? {
        guard let state = marketState else { return nil }
        return MarketState(rawValue: state)
    }

    var effectivePrice: Double {
        guard let state = marketStateEnum else { return close }
        switch state {
        case .pre, .prepre:
            return preMarketPrice ?? close
        case .post, .postpost:
            return postMarketPrice ?? close
        case .regular, .closed:
            return close
        }
    }

    // MARK: - Upsert Helper

    /// 更新现有缓存或插入新缓存（避免唯一约束冲突）
    @MainActor
    static func upsert(
        data: PriceCacheData,
        modelContext: ModelContext
    ) throws {
        let symbol = data.symbol
        let dateStart = data.date.startOfDay
        let dateEnd = dateStart.adding(days: 1)

        // 查找现有记录
        let predicate = #Predicate<PriceCache> {
            $0.symbol == symbol && $0.date >= dateStart && $0.date < dateEnd
        }
        var descriptor = FetchDescriptor<PriceCache>(predicate: predicate)
        descriptor.fetchLimit = 1

        let existing = try modelContext.fetch(descriptor)

        if let cache = existing.first {
            // 更新现有记录
            cache.open = data.open
            cache.high = data.high
            cache.low = data.low
            cache.close = data.close
            cache.currency = data.currency
            cache.preMarketPrice = data.preMarketPrice
            cache.postMarketPrice = data.postMarketPrice
            cache.marketState = data.marketState
        } else {
            // 插入新记录
            let newCache = PriceCache(
                symbol: data.symbol,
                date: data.date,
                open: data.open,
                high: data.high,
                low: data.low,
                close: data.close,
                currency: data.currency,
                preMarketPrice: data.preMarketPrice,
                postMarketPrice: data.postMarketPrice,
                marketState: data.marketState
            )
            modelContext.insert(newCache)
        }
    }

    /// 批量 upsert
    @MainActor
    static func upsertBatch(
        dataList: [PriceCacheData],
        modelContext: ModelContext
    ) throws {
        for data in dataList {
            try upsert(data: data, modelContext: modelContext)
        }
        try modelContext.save()
    }
}
