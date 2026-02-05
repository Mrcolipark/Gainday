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

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        totalValue: Double = 0,
        totalCost: Double = 0,
        dailyPnL: Double = 0,
        dailyPnLPercent: Double = 0,
        cumulativePnL: Double = 0,
        breakdownJSON: String = "{}"
    ) {
        self.id = id
        self.date = date
        self.totalValue = totalValue
        self.totalCost = totalCost
        self.dailyPnL = dailyPnL
        self.dailyPnLPercent = dailyPnLPercent
        self.cumulativePnL = cumulativePnL
        self.breakdownJSON = breakdownJSON
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
}
