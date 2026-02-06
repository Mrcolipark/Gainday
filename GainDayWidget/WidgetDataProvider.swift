import Foundation
import WidgetKit
import SwiftData
import SwiftUI

// MARK: - Widget Color Helpers

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

enum WidgetColors {
    // Use same colors as AppColors for consistency
    static let profit = Color(hex: 0x34C759)
    static let loss = Color(hex: 0xFF3B30)
    // Legacy aliases for compatibility
    static let changeBadgeGreen = profit
    static let changeBadgeRed = loss

    /// 12+ stop saturated heatmap colors matching AppColors.pnlColor (High Contrast)
    static func pnlColor(percent: Double) -> Color {
        switch percent {
        case ..<(-5):   return Color(hex: 0xB71C1C)   // deep crimson
        case ..<(-3):   return Color(hex: 0xC62828)   // dark red
        case ..<(-2):   return Color(hex: 0xD32F2F)   // crimson
        case ..<(-1):   return Color(hex: 0xE53935)   // red
        case ..<(-0.5): return Color(hex: 0xEF5350)   // coral red
        case ..<0:      return Color(hex: 0xF44336)   // medium red
        case 0:         return Color(hex: 0x616161)   // neutral dark gray
        case ..<0.5:    return Color(hex: 0x4CAF50)   // medium green
        case ..<1:      return Color(hex: 0x43A047)   // green
        case ..<2:      return Color(hex: 0x388E3C)   // darker green
        case ..<3:      return Color(hex: 0x2E7D32)   // deep green
        case ..<5:      return Color(hex: 0x1B5E20)   // darkest green
        default:        return Color(hex: 0x0D5302)   // ultra deep green
        }
    }
}

struct WidgetPnLData {
    let totalValue: Double
    let dailyPnL: Double
    let dailyPnLPercent: Double
    let baseCurrency: String
    let date: Date

    static let placeholder = WidgetPnLData(
        totalValue: 1_234_567,
        dailyPnL: 12_340,
        dailyPnLPercent: 1.23,
        baseCurrency: "JPY",
        date: Date()
    )
}

struct WidgetDayPnL: Identifiable {
    let id = UUID()
    let date: Date
    let pnl: Double
    let pnlPercent: Double

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

struct WidgetMonthData {
    let month: Date
    let totalPnL: Double
    let days: [Date: Double] // date -> pnlPercent
    let profitDays: Int
    let lossDays: Int
    let winRate: Double
    let baseCurrency: String

    static let placeholder: WidgetMonthData = {
        let now = Date()
        return WidgetMonthData(
            month: now,
            totalPnL: 32_100,
            days: [:],
            profitDays: 14,
            lossDays: 8,
            winRate: 63.6,
            baseCurrency: "JPY"
        )
    }()
}

// MARK: - Data Loading

@MainActor
struct WidgetDataLoader {
    static func loadLatestPnL() -> WidgetPnLData {
        do {
            let schema = Schema([DailySnapshot.self, Portfolio.self, Holding.self, Transaction.self, PriceCache.self])
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext

            let descriptor = FetchDescriptor<DailySnapshot>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )

            let snapshots = try context.fetch(descriptor)

            // 只获取全局快照（portfolioID == nil）
            if let latest = snapshots.first(where: { $0.portfolioID == nil }) {
                return WidgetPnLData(
                    totalValue: latest.totalValue,
                    dailyPnL: latest.dailyPnL,
                    dailyPnLPercent: latest.dailyPnLPercent,
                    baseCurrency: "JPY",
                    date: latest.date
                )
            }
        } catch {
            // Fall through to placeholder
        }

        return .placeholder
    }

    static func loadWeekPnL() -> [WidgetDayPnL] {
        do {
            let schema = Schema([DailySnapshot.self, Portfolio.self, Holding.self, Transaction.self, PriceCache.self])
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext

            let weekStart = Date().startOfWeek
            let weekEnd = weekStart.adding(days: 7)

            let descriptor = FetchDescriptor<DailySnapshot>(
                sortBy: [SortDescriptor(\.date)]
            )

            let snapshots = try context.fetch(descriptor)

            // 只获取全局快照并按日期过滤
            return snapshots
                .filter { $0.portfolioID == nil && $0.date >= weekStart && $0.date < weekEnd }
                .map { WidgetDayPnL(date: $0.date, pnl: $0.dailyPnL, pnlPercent: $0.dailyPnLPercent) }
        } catch {
            return []
        }
    }

    static func loadMonthData() -> WidgetMonthData {
        do {
            let schema = Schema([DailySnapshot.self, Portfolio.self, Holding.self, Transaction.self, PriceCache.self])
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext

            let now = Date()
            let monthStart = now.startOfMonth
            let monthEnd = now.endOfMonth.adding(days: 1)

            let descriptor = FetchDescriptor<DailySnapshot>(
                sortBy: [SortDescriptor(\.date)]
            )

            let allSnapshots = try context.fetch(descriptor)

            // 只获取全局快照并按日期过滤
            let snapshots = allSnapshots.filter {
                $0.portfolioID == nil && $0.date >= monthStart && $0.date < monthEnd
            }

            var dayPcts: [Date: Double] = [:]
            for snap in snapshots {
                dayPcts[snap.date.startOfDay] = snap.dailyPnLPercent
            }

            let totalPnL = snapshots.reduce(0) { $0 + $1.dailyPnL }
            let profitDays = snapshots.filter { $0.dailyPnL > 0 }.count
            let lossDays = snapshots.filter { $0.dailyPnL < 0 }.count
            let total = profitDays + lossDays
            let winRate = total > 0 ? Double(profitDays) / Double(total) * 100 : 0

            return WidgetMonthData(
                month: now,
                totalPnL: totalPnL,
                days: dayPcts,
                profitDays: profitDays,
                lossDays: lossDays,
                winRate: winRate,
                baseCurrency: "JPY"
            )
        } catch {
            return .placeholder
        }
    }
}
