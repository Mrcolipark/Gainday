import Foundation
import WidgetKit
import SwiftData
import SwiftUI

// MARK: - Double Extension for Widget

extension Double {
    func currencyFormatted(code: String = "JPY", compact: Bool = false, showSign: Bool = false) -> String {
        if compact {
            let absValue = abs(self)
            if absValue >= 1_000_000_000 {
                return "\(Int(absValue / 1_000_000_000))B"
            } else if absValue >= 1_000_000 {
                return "\(Int(absValue / 1_000_000))M"
            } else if absValue >= 1_000 {
                return "\(Int(absValue / 1_000))K"
            }
        }

        let formatted = self.formatted(
            .currency(code: code)
            .precision(.fractionLength(code == "JPY" ? 0 : 2))
        )
        if showSign && self > 0 {
            return "+\(formatted)"
        }
        return formatted
    }

    func percentFormatted(showSign: Bool = true) -> String {
        let sign = showSign && self > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", self))%"
    }

    func compactFormatted(code: String = "JPY", showSign: Bool = false) -> String {
        let absValue = abs(self)
        let sign: String
        if self < 0 {
            sign = "-"
        } else if showSign && self > 0 {
            sign = "+"
        } else {
            sign = ""
        }
        let currencySymbol: String
        switch code {
        case "JPY": currencySymbol = "¥"
        case "CNY": currencySymbol = "¥"
        case "USD": currencySymbol = "$"
        case "HKD": currencySymbol = "HK$"
        default: currencySymbol = code
        }

        if absValue >= 100_000_000 {
            return "\(sign)\(currencySymbol)\(String(format: "%.1f", absValue / 100_000_000))亿"
        } else if absValue >= 10_000 {
            return "\(sign)\(currencySymbol)\(String(format: "%.1f", absValue / 10_000))万"
        } else {
            return "\(sign)\(currencySymbol)\(String(format: "%.0f", absValue))"
        }
    }
}

// MARK: - Date Extension for Widget

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    var endOfMonth: Date {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) else { return self }
        return Calendar.current.date(byAdding: .day, value: -1, to: nextMonth) ?? self
    }

    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    var year: Int { Calendar.current.component(.year, from: self) }
    var month: Int { Calendar.current.component(.month, from: self) }
    var day: Int { Calendar.current.component(.day, from: self) }
    var weekday: Int { Calendar.current.component(.weekday, from: self) }

    var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: self)?.count ?? 30
    }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: self)
    }

    var dayString: String {
        "\(day)"
    }

    func calendarDays() -> [Date?] {
        let calendar = Calendar.current
        let firstDay = startOfMonth
        let firstWeekday = firstDay.weekday
        let totalDays = daysInMonth

        var days: [Date?] = []

        let offset = firstWeekday - 1
        for _ in 0..<offset {
            days.append(nil)
        }

        for day in 1...totalDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }
}

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

// MARK: - Holdings Widget Data

struct WidgetHolding: Identifiable {
    let id: String  // symbol
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let changePercent: Double
    let currency: String
    let marketValue: Double
}

struct WidgetHoldingsData {
    let holdings: [WidgetHolding]
    let lastUpdate: Date
    let baseCurrency: String

    static let placeholder = WidgetHoldingsData(
        holdings: [
            WidgetHolding(id: "AAPL", symbol: "AAPL", name: "Apple Inc.", price: 182.63, change: 2.25, changePercent: 1.25, currency: "USD", marketValue: 18263),
            WidgetHolding(id: "MSFT", symbol: "MSFT", name: "Microsoft", price: 420.00, change: 3.55, changePercent: 0.85, currency: "USD", marketValue: 42000),
            WidgetHolding(id: "7203.T", symbol: "7203.T", name: "トヨタ自動車", price: 2845, change: -9.12, changePercent: -0.32, currency: "JPY", marketValue: 284500),
            WidgetHolding(id: "9984.T", symbol: "9984.T", name: "ソフトバンクG", price: 8120, change: 167.28, changePercent: 2.10, currency: "JPY", marketValue: 812000),
        ],
        lastUpdate: Date(),
        baseCurrency: "JPY"
    )
}

// MARK: - Market Indices Widget Data

struct WidgetIndex: Identifiable {
    let id: String  // symbol
    let symbol: String      // ^GSPC, ^N225, ^HSI
    let name: String        // S&P 500, 日経225, 恒生指数
    let value: Double
    let change: Double
    let changePercent: Double
    let flag: String        // 🇺🇸, 🇯🇵, 🇭🇰
}

struct WidgetIndicesData {
    let indices: [WidgetIndex]
    let lastUpdate: Date

    static let placeholder = WidgetIndicesData(
        indices: [
            WidgetIndex(id: "^GSPC", symbol: "^GSPC", name: "S&P 500", value: 5234.18, change: 44.06, changePercent: 0.85, flag: "🇺🇸"),
            WidgetIndex(id: "^N225", symbol: "^N225", name: "日経225", value: 38460.08, change: -123.15, changePercent: -0.32, flag: "🇯🇵"),
            WidgetIndex(id: "^HSI", symbol: "^HSI", name: "恒生指数", value: 18234.56, change: 216.12, changePercent: 1.20, flag: "🇭🇰"),
            WidgetIndex(id: "000001.SS", symbol: "000001.SS", name: "上证指数", value: 3045.67, change: 13.65, changePercent: 0.45, flag: "🇨🇳"),
        ],
        lastUpdate: Date()
    )
}

// MARK: - Data Loading

@MainActor
struct WidgetDataLoader {
    /// 获取用户基准货币（从第一个 Portfolio 获取，默认 JPY）
    static func getUserBaseCurrency(context: ModelContext) -> String {
        do {
            var descriptor = FetchDescriptor<Portfolio>(
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            descriptor.fetchLimit = 1
            let portfolios = try context.fetch(descriptor)
            return portfolios.first?.baseCurrency ?? "JPY"
        } catch {
            return "JPY"
        }
    }

    /// 创建共享的 ModelContainer
    private static func createContainer() throws -> ModelContainer {
        let schema = Schema([DailySnapshot.self, Portfolio.self, Holding.self, Transaction.self, PriceCache.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        return try ModelContainer(for: schema, configurations: [config])
    }

    static func loadLatestPnL() -> WidgetPnLData {
        do {
            let container = try createContainer()
            let context = container.mainContext
            let baseCurrency = getUserBaseCurrency(context: context)

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
                    baseCurrency: baseCurrency,
                    date: latest.date
                )
            }
        } catch {
            // Fall through to placeholder
        }

        return .placeholder
    }

    static func loadWeekPnL() -> (days: [WidgetDayPnL], baseCurrency: String) {
        do {
            let container = try createContainer()
            let context = container.mainContext
            let baseCurrency = getUserBaseCurrency(context: context)

            let weekStart = Date().startOfWeek
            let weekEnd = weekStart.adding(days: 7)

            let descriptor = FetchDescriptor<DailySnapshot>(
                sortBy: [SortDescriptor(\.date)]
            )

            let snapshots = try context.fetch(descriptor)

            // 只获取全局快照并按日期过滤
            let days = snapshots
                .filter { $0.portfolioID == nil && $0.date >= weekStart && $0.date < weekEnd }
                .map { WidgetDayPnL(date: $0.date, pnl: $0.dailyPnL, pnlPercent: $0.dailyPnLPercent) }
            return (days, baseCurrency)
        } catch {
            return ([], "JPY")
        }
    }

    static func loadMonthData() -> WidgetMonthData {
        do {
            let container = try createContainer()
            let context = container.mainContext
            let baseCurrency = getUserBaseCurrency(context: context)

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
                baseCurrency: baseCurrency
            )
        } catch {
            return .placeholder
        }
    }

    // MARK: - Holdings Data Loading

    static func loadTopHoldings(limit: Int = 5) -> WidgetHoldingsData {
        do {
            let container = try createContainer()
            let context = container.mainContext
            let baseCurrency = getUserBaseCurrency(context: context)

            // 获取所有持仓
            let holdingDescriptor = FetchDescriptor<Holding>()
            let holdings = try context.fetch(holdingDescriptor)

            // 获取今日的价格缓存
            let today = Date().startOfDay
            let tomorrow = today.adding(days: 1)
            let pricePredicate = #Predicate<PriceCache> { $0.date >= today && $0.date < tomorrow }
            var priceDescriptor = FetchDescriptor<PriceCache>(predicate: pricePredicate)
            let prices = try context.fetch(priceDescriptor)

            // 构建 symbol -> PriceCache 映射
            var priceMap: [String: PriceCache] = [:]
            for price in prices {
                priceMap[price.symbol] = price
            }

            // 获取昨日价格用于计算涨跌幅
            let yesterday = today.adding(days: -1)
            let yesterdayEnd = today
            let yesterdayPredicate = #Predicate<PriceCache> { $0.date >= yesterday && $0.date < yesterdayEnd }
            var yesterdayDescriptor = FetchDescriptor<PriceCache>(predicate: yesterdayPredicate)
            let yesterdayPrices = try context.fetch(yesterdayDescriptor)

            var yesterdayPriceMap: [String: Double] = [:]
            for price in yesterdayPrices {
                yesterdayPriceMap[price.symbol] = price.close
            }

            // 转换为 WidgetHolding 并按市值排序
            var widgetHoldings: [WidgetHolding] = []

            for holding in holdings {
                let quantity = holding.totalQuantity
                guard quantity > 0 else { continue }

                let symbol = holding.symbol
                guard let priceCache = priceMap[symbol] else { continue }

                let currentPrice = priceCache.effectivePrice
                let previousClose = yesterdayPriceMap[symbol] ?? priceCache.open
                let change = currentPrice - previousClose
                let changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0
                let marketValue = currentPrice * quantity

                widgetHoldings.append(WidgetHolding(
                    id: symbol,
                    symbol: symbol,
                    name: holding.name,
                    price: currentPrice,
                    change: change,
                    changePercent: changePercent,
                    currency: priceCache.currency,
                    marketValue: marketValue
                ))
            }

            // 按市值排序，取前 N 个
            widgetHoldings.sort { $0.marketValue > $1.marketValue }
            let topHoldings = Array(widgetHoldings.prefix(limit))

            return WidgetHoldingsData(
                holdings: topHoldings,
                lastUpdate: Date(),
                baseCurrency: baseCurrency
            )
        } catch {
            return .placeholder
        }
    }

    // MARK: - Market Indices Data Loading

    static func loadMarketIndices() -> WidgetIndicesData {
        // 预设指数列表
        let defaultIndices: [(symbol: String, name: String, flag: String)] = [
            ("^GSPC", "S&P 500", "🇺🇸"),
            ("^N225", "日経225", "🇯🇵"),
            ("^HSI", "恒生指数", "🇭🇰"),
            ("000001.SS", "上证指数", "🇨🇳")
        ]

        do {
            let container = try createContainer()
            let context = container.mainContext

            // 获取今日的价格缓存
            let today = Date().startOfDay
            let tomorrow = today.adding(days: 1)
            let symbols = defaultIndices.map { $0.symbol }

            var priceDescriptor = FetchDescriptor<PriceCache>()
            let allPrices = try context.fetch(priceDescriptor)

            // 获取每个指数的最新价格
            var priceMap: [String: PriceCache] = [:]
            for symbol in symbols {
                // 获取该 symbol 最近的价格
                if let latestPrice = allPrices
                    .filter({ $0.symbol == symbol })
                    .sorted(by: { $0.date > $1.date })
                    .first {
                    priceMap[symbol] = latestPrice
                }
            }

            // 获取昨日价格
            let yesterday = today.adding(days: -1)
            var yesterdayPriceMap: [String: Double] = [:]
            for symbol in symbols {
                if let yesterdayPrice = allPrices
                    .filter({ $0.symbol == symbol && $0.date >= yesterday && $0.date < today })
                    .first {
                    yesterdayPriceMap[symbol] = yesterdayPrice.close
                }
            }

            // 构建指数数据
            var indices: [WidgetIndex] = []

            for indexInfo in defaultIndices {
                guard let priceCache = priceMap[indexInfo.symbol] else { continue }

                let currentValue = priceCache.effectivePrice
                let previousClose = yesterdayPriceMap[indexInfo.symbol] ?? priceCache.open
                let change = currentValue - previousClose
                let changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0

                indices.append(WidgetIndex(
                    id: indexInfo.symbol,
                    symbol: indexInfo.symbol,
                    name: indexInfo.name,
                    value: currentValue,
                    change: change,
                    changePercent: changePercent,
                    flag: indexInfo.flag
                ))
            }

            // 如果没有数据，返回 placeholder
            if indices.isEmpty {
                return .placeholder
            }

            return WidgetIndicesData(
                indices: indices,
                lastUpdate: Date()
            )
        } catch {
            return .placeholder
        }
    }
}
