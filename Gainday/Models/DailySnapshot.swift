import Foundation
import SwiftData

@Model
class DailySnapshot {
    var id: UUID
    var date: Date
    var totalValue: Double
    var totalCost: Double
    var dailyPnL: Double
    var dailyPnLPercent: Double
    var cumulativePnL: Double
    var breakdownJSON: String

    /// 持仓级别的当日盈亏明细 JSON
    var holdingPnLJSON: String

    /// 账户ID - nil 表示全局汇总，有值表示特定账户的快照
    var portfolioID: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        totalValue: Double = 0,
        totalCost: Double = 0,
        dailyPnL: Double = 0,
        dailyPnLPercent: Double = 0,
        cumulativePnL: Double = 0,
        breakdownJSON: String = "[]",
        holdingPnLJSON: String = "[]",
        portfolioID: String? = nil
    ) {
        self.id = id
        self.date = date
        self.totalValue = totalValue
        self.totalCost = totalCost
        self.dailyPnL = dailyPnL
        self.dailyPnLPercent = dailyPnLPercent
        self.cumulativePnL = cumulativePnL
        self.breakdownJSON = breakdownJSON
        self.holdingPnLJSON = holdingPnLJSON
        self.portfolioID = portfolioID
    }

    /// 是否是全局汇总快照
    var isGlobalSnapshot: Bool {
        portfolioID == nil
    }

    var dateOnly: Date {
        Calendar.current.startOfDay(for: date)
    }

    var unrealizedPnL: Double {
        totalValue - totalCost
    }

    var unrealizedPnLPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (totalValue - totalCost) / totalCost * 100
    }
}

// MARK: - Breakdown

struct AssetBreakdown: Codable {
    var assetType: String
    var value: Double
    var cost: Double
    var pnl: Double
    var currency: String
}

/// 单个持仓的当日盈亏明细
struct HoldingDailyPnL: Codable {
    var symbol: String
    var name: String
    var dailyPnL: Double
    var dailyPnLPercent: Double
    var marketValue: Double
}


extension DailySnapshot {
    var breakdown: [AssetBreakdown] {
        guard let data = breakdownJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([AssetBreakdown].self, from: data)) ?? []
    }

    func setBreakdown(_ items: [AssetBreakdown]) {
        if let data = try? JSONEncoder().encode(items),
           let json = String(data: data, encoding: .utf8) {
            breakdownJSON = json
        }
    }

    /// 获取持仓级别的当日盈亏明细
    var holdingPnLs: [HoldingDailyPnL] {
        guard let data = holdingPnLJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([HoldingDailyPnL].self, from: data)) ?? []
    }

    /// 设置持仓级别的当日盈亏明细
    func setHoldingPnLs(_ items: [HoldingDailyPnL]) {
        if let data = try? JSONEncoder().encode(items),
           let json = String(data: data, encoding: .utf8) {
            holdingPnLJSON = json
        }
    }

    /// 获取波动最大的前N个持仓（按绝对值排序）
    func topMovers(limit: Int = 5) -> [HoldingDailyPnL] {
        holdingPnLs
            .sorted { abs($0.dailyPnL) > abs($1.dailyPnL) }
            .prefix(limit)
            .map { $0 }
    }
}
