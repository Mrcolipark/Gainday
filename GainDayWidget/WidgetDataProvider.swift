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

    /// 12+ stop saturated heatmap colors matching AppColors.pnlColor
    static func pnlColor(percent: Double) -> Color {
        switch percent {
        case ..<(-5):   return Color(hex: 0xB71C1C)   // deep crimson
        case ..<(-3):   return Color(hex: 0xD32F2F)   // crimson
        case ..<(-2):   return Color(hex: 0xE53935)   // red
        case ..<(-1):   return Color(hex: 0xEF5350)   // light red
        case ..<(-0.5): return Color(hex: 0xE57373)   // coral
        case ..<0:      return Color(hex: 0xFFCDD2)   // muted pink
        case 0:         return Color(hex: 0xE0E0E0)   // neutral gray
        case ..<0.5:    return Color(hex: 0xC8E6C9)   // pale green
        case ..<1:      return Color(hex: 0xA5D6A7)   // light green
        case ..<2:      return Color(hex: 0x66BB6A)   // emerald
        case ..<3:      return Color(hex: 0x43A047)   // green
        case ..<5:      return Color(hex: 0x2E7D32)   // deep green
        default:        return Color(hex: 0x1B5E20)   // darkest green
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

            var descriptor = FetchDescriptor<DailySnapshot>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            descriptor.fetchLimit = 1

            let snapshots = try context.fetch(descriptor)

            if let latest = snapshots.first {
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

            let predicate = #Predicate<DailySnapshot> {
                $0.date >= weekStart && $0.date < weekEnd
            }
            let descriptor = FetchDescriptor<DailySnapshot>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date)]
            )

            let snapshots = try context.fetch(descriptor)
            return snapshots.map {
                WidgetDayPnL(date: $0.date, pnl: $0.dailyPnL, pnlPercent: $0.dailyPnLPercent)
            }
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

            let predicate = #Predicate<DailySnapshot> {
                $0.date >= monthStart && $0.date < monthEnd
            }
            let descriptor = FetchDescriptor<DailySnapshot>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date)]
            )

            let snapshots = try context.fetch(descriptor)

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
