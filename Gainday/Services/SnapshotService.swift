import Foundation
import SwiftData
import WidgetKit

@MainActor
class SnapshotService {
    static let shared = SnapshotService()

    private init() {}

    // MARK: - 生成每日快照

    /// 生成今日快照 - 为每个账户生成独立快照 + 全局汇总快照
    func saveOrUpdateTodaySnapshot(
        portfolios: [Portfolio],
        quotes: [String: MarketDataService.QuoteData],
        rates: [String: Double],
        baseCurrency: String,
        modelContext: ModelContext
    ) async {
        let today = Date().startOfDay
        let weekday = Calendar.current.component(.weekday, from: today)
        let isWeekend = weekday == 1 || weekday == 7

        // 如果没有持仓，跳过
        let hasHoldings = portfolios.contains { !$0.holdings.isEmpty }
        guard hasHoldings else { return }

        let calcService = PnLCalculationService.shared

        // 全局汇总数据
        var globalValue: Double = 0
        var globalCost: Double = 0
        var globalDailyPnL: Double = 0
        var assetTypeValues: [String: (value: Double, cost: Double, pnl: Double)] = [:]
        var allHoldingPnLs: [HoldingDailyPnL] = []

        do {
            // 为每个账户计算盈亏
            for portfolio in portfolios {
                guard !portfolio.holdings.isEmpty else { continue }

                let portfolioPnL = calcService.calculatePortfolioPnL(
                    portfolio: portfolio,
                    quotes: quotes,
                    rates: rates
                )

                let portfolioCurrency = portfolio.baseCurrency
                let portfolioRate = rates["\(portfolioCurrency)\(baseCurrency)"] ?? 1.0

                let valueInBase = portfolioPnL.totalValue * portfolioRate
                let costInBase = portfolioPnL.totalCost * portfolioRate
                let dailyPnLInBase = portfolioPnL.dailyPnL * portfolioRate

                // 累加到全局
                globalValue += valueInBase
                globalCost += costInBase
                globalDailyPnL += dailyPnLInBase

                // 资产类型分解 + 个股盈亏
                for hpnl in portfolioPnL.holdingPnLs {
                    let assetType = hpnl.holding.assetType
                    var existing = assetTypeValues[assetType] ?? (value: 0, cost: 0, pnl: 0)
                    existing.value += hpnl.marketValue * portfolioRate
                    existing.cost += hpnl.costBasis * portfolioRate
                    existing.pnl += hpnl.dailyPnL * portfolioRate
                    assetTypeValues[assetType] = existing

                    // 收集个股盈亏
                    let holdingDailyPnL = HoldingDailyPnL(
                        symbol: hpnl.holding.symbol,
                        name: hpnl.holding.name,
                        dailyPnL: hpnl.dailyPnL * portfolioRate,
                        dailyPnLPercent: hpnl.dailyPnLPercent,
                        marketValue: hpnl.marketValue * portfolioRate
                    )
                    allHoldingPnLs.append(holdingDailyPnL)
                }

                // 周末跳过保存快照到 SwiftData
                if !isWeekend {
                    let dailyPnLPercent = (valueInBase - dailyPnLInBase) > 0
                        ? (dailyPnLInBase / (valueInBase - dailyPnLInBase)) * 100
                        : 0

                    try saveOrUpdateSnapshot(
                        date: today,
                        portfolioID: portfolio.id.uuidString,
                        totalValue: valueInBase,
                        totalCost: costInBase,
                        dailyPnL: dailyPnLInBase,
                        dailyPnLPercent: dailyPnLPercent,
                        cumulativePnL: valueInBase - costInBase,
                        modelContext: modelContext
                    )
                }
            }

            // 生成全局汇总快照（仅工作日保存到 SwiftData）
            let globalDailyPnLPercent = (globalValue - globalDailyPnL) > 0
                ? (globalDailyPnL / (globalValue - globalDailyPnL)) * 100
                : 0

            if !isWeekend {
                var breakdownItems: [AssetBreakdown] = []
                for (assetType, values) in assetTypeValues {
                    breakdownItems.append(AssetBreakdown(
                        assetType: assetType,
                        value: values.value,
                        cost: values.cost,
                        pnl: values.pnl,
                        currency: baseCurrency
                    ))
                }

                try saveOrUpdateSnapshot(
                    date: today,
                    portfolioID: nil,
                    totalValue: globalValue,
                    totalCost: globalCost,
                    dailyPnL: globalDailyPnL,
                    dailyPnLPercent: globalDailyPnLPercent,
                    cumulativePnL: globalValue - globalCost,
                    breakdown: breakdownItems,
                    holdingPnLs: allHoldingPnLs,
                    modelContext: modelContext
                )

                try modelContext.save()
            }

            // 始终同步 Widget 数据（包括周末）
            syncToWidgetDefaults(
                totalValue: globalValue,
                dailyPnL: globalDailyPnL,
                dailyPnLPercent: globalDailyPnLPercent,
                baseCurrency: baseCurrency,
                holdings: portfolios.flatMap(\.holdings).filter { $0.totalQuantity > 0 }
            )

            // 将当月每日盈亏数据写入 UserDefaults，供 MonthHeatmapWidget 使用
            syncMonthDataToWidget(modelContext: modelContext)

            // 通知 Widget 刷新数据
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Failed to save snapshots: \(error)")
        }
    }

    // MARK: - Widget Data Sync

    private static let appGroupID = "group.com.gainday.shared"

    /// 将关键数据写入 App Group UserDefaults，Widget 直接读取
    private func syncToWidgetDefaults(
        totalValue: Double,
        dailyPnL: Double,
        dailyPnLPercent: Double,
        baseCurrency: String,
        holdings: [Holding]
    ) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }

        // PnL 数据
        defaults.set(totalValue, forKey: "widget_totalValue")
        defaults.set(dailyPnL, forKey: "widget_dailyPnL")
        defaults.set(dailyPnLPercent, forKey: "widget_dailyPnLPercent")
        defaults.set(baseCurrency, forKey: "widget_baseCurrency")
        defaults.set(Date().timeIntervalSince1970, forKey: "widget_lastUpdate")

        // 持仓列表（供 WatchlistWidget 使用）
        let holdingsList = holdings.prefix(6).map { h -> [String: Any] in
            let market = Market(rawValue: h.market) ?? .JP
            return [
                "symbol": h.symbol,
                "name": h.name,
                "currency": market.currency
            ]
        }
        defaults.set(holdingsList, forKey: "widget_holdings")
    }

    /// 将当月每日盈亏数据写入 App Group UserDefaults，供 MonthHeatmapWidget 使用
    private func syncMonthDataToWidget(modelContext: ModelContext) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }

        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return }

        do {
            let allSnapshots = try modelContext.fetch(FetchDescriptor<DailySnapshot>())
            let monthSnapshots = allSnapshots.filter { snap in
                snap.portfolioID == nil && snap.date >= monthStart && snap.date < monthEnd
            }

            // 序列化为 [[String: Any]] 格式
            let monthData = monthSnapshots.map { snap -> [String: Any] in
                let day = calendar.component(.day, from: snap.date)
                return [
                    "day": day,
                    "dailyPnL": snap.dailyPnL,
                    "dailyPnLPercent": snap.dailyPnLPercent
                ]
            }

            defaults.set(monthData, forKey: "widget_monthPnL")
            defaults.set(year, forKey: "widget_monthPnL_year")
            defaults.set(month, forKey: "widget_monthPnL_month")
        } catch {
            print("Failed to sync month data to widget: \(error)")
        }
    }

    /// 保存或更新单个快照
    private func saveOrUpdateSnapshot(
        date: Date,
        portfolioID: String?,
        totalValue: Double,
        totalCost: Double,
        dailyPnL: Double,
        dailyPnLPercent: Double,
        cumulativePnL: Double,
        breakdown: [AssetBreakdown] = [],
        holdingPnLs: [HoldingDailyPnL] = [],
        modelContext: ModelContext
    ) throws {
        let dayStart = date.startOfDay
        let dayEnd = date.adding(days: 1).startOfDay

        // 查找现有快照
        let existing: DailySnapshot? = try {
            let allSnapshots = try modelContext.fetch(FetchDescriptor<DailySnapshot>())
            return allSnapshots.first { snap in
                snap.date >= dayStart && snap.date < dayEnd && snap.portfolioID == portfolioID
            }
        }()

        if let existingSnapshot = existing {
            // 更新现有快照
            existingSnapshot.totalValue = totalValue
            existingSnapshot.totalCost = totalCost
            existingSnapshot.dailyPnL = dailyPnL
            existingSnapshot.dailyPnLPercent = dailyPnLPercent
            existingSnapshot.cumulativePnL = cumulativePnL
            if !breakdown.isEmpty {
                existingSnapshot.setBreakdown(breakdown)
            }
            if !holdingPnLs.isEmpty {
                existingSnapshot.setHoldingPnLs(holdingPnLs)
            }
        } else {
            // 创建新快照
            let snapshot = DailySnapshot(
                date: dayStart,
                totalValue: totalValue,
                totalCost: totalCost,
                dailyPnL: dailyPnL,
                dailyPnLPercent: dailyPnLPercent,
                cumulativePnL: cumulativePnL,
                portfolioID: portfolioID
            )
            if !breakdown.isEmpty {
                snapshot.setBreakdown(breakdown)
            }
            if !holdingPnLs.isEmpty {
                snapshot.setHoldingPnLs(holdingPnLs)
            }
            modelContext.insert(snapshot)
        }
    }

    // MARK: - 查询快照

    /// 获取指定月份的快照（支持按账户筛选）
    func fetchSnapshots(
        for month: Date,
        portfolioID: String? = nil,
        modelContext: ModelContext
    ) throws -> [DailySnapshot] {
        let startOfMonth = month.startOfMonth
        let endOfMonth = month.endOfMonth.adding(days: 1)

        let allSnapshots = try modelContext.fetch(FetchDescriptor<DailySnapshot>())

        return allSnapshots.filter { snap in
            snap.date >= startOfMonth && snap.date < endOfMonth && snap.portfolioID == portfolioID
        }.sorted { $0.date < $1.date }
    }

    /// 获取指定日期范围的快照
    func fetchSnapshots(
        from startDate: Date,
        to endDate: Date,
        portfolioID: String? = nil,
        modelContext: ModelContext
    ) throws -> [DailySnapshot] {
        let start = startDate.startOfDay
        let end = endDate.adding(days: 1).startOfDay

        let allSnapshots = try modelContext.fetch(FetchDescriptor<DailySnapshot>())

        return allSnapshots.filter { snap in
            snap.date >= start && snap.date < end && snap.portfolioID == portfolioID
        }.sorted { $0.date < $1.date }
    }

    /// 获取年度所有快照（用于年度热力图）
    func fetchYearSnapshots(
        year: Int,
        portfolioID: String? = nil,
        modelContext: ModelContext
    ) throws -> [DailySnapshot] {
        let calendar = Calendar.current
        guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return []
        }

        let allSnapshots = try modelContext.fetch(FetchDescriptor<DailySnapshot>())

        return allSnapshots.filter { snap in
            snap.date >= startOfYear && snap.date < endOfYear && snap.portfolioID == portfolioID
        }.sorted { $0.date < $1.date }
    }

    /// 获取最近一个交易日的全局快照
    func getLatestSnapshot(modelContext: ModelContext) throws -> DailySnapshot? {
        let allSnapshots = try modelContext.fetch(FetchDescriptor<DailySnapshot>())

        return allSnapshots
            .filter { $0.portfolioID == nil }
            .sorted { $0.date > $1.date }
            .first
    }

    /// 检查指定日期是否存在全局快照
    func snapshotExists(for date: Date, modelContext: ModelContext) throws -> Bool {
        let dayStart = date.startOfDay
        let dayEnd = date.adding(days: 1).startOfDay

        let allSnapshots = try modelContext.fetch(FetchDescriptor<DailySnapshot>())

        return allSnapshots.contains { snap in
            snap.date >= dayStart && snap.date < dayEnd && snap.portfolioID == nil
        }
    }

    // MARK: - 历史数据迁移

    /// 为账户生成历史快照数据（基于交易记录和历史价格）
    func migrateHistoricalSnapshots(
        portfolios: [Portfolio],
        baseCurrency: String,
        modelContext: ModelContext
    ) async {
        do {
            let allSnapshots = try modelContext.fetch(FetchDescriptor<DailySnapshot>())
            print("[Migration] Total snapshots in DB: \(allSnapshots.count)")

            // 找出每个账户已有快照的日期
            var existingDatesPerPortfolio: [String: Set<Date>] = [:]
            for snapshot in allSnapshots {
                if let portfolioID = snapshot.portfolioID {
                    var dates = existingDatesPerPortfolio[portfolioID] ?? []
                    dates.insert(snapshot.date.startOfDay)
                    existingDatesPerPortfolio[portfolioID] = dates
                }
            }

            // 收集所有股票代码
            var allSymbols: Set<String> = []
            var symbolMarkets: [String: Market] = [:]
            for portfolio in portfolios {
                for holding in portfolio.holdings {
                    allSymbols.insert(holding.symbol)
                    symbolMarkets[holding.symbol] = holding.marketEnum
                }
            }

            guard !allSymbols.isEmpty else {
                print("[Migration] No holdings found, skipping")
                return
            }

            // 获取历史价格
            print("[Migration] Fetching historical prices for \(allSymbols.count) symbols...")
            var historicalPrices: [String: [Date: Double]] = [:]
            for symbol in allSymbols {
                let market = symbolMarkets[symbol] ?? .US
                if market == .JP_FUND {
                    print("[Migration] Skipping JP_FUND: \(symbol)")
                    continue
                }

                if let chartData = try? await MarketDataService.shared.fetchChartData(
                    symbol: symbol,
                    interval: "1d",
                    range: "1y"
                ) {
                    var priceMap: [Date: Double] = [:]
                    for data in chartData {
                        priceMap[data.date.startOfDay] = data.close
                    }
                    historicalPrices[symbol] = priceMap
                    print("[Migration] Got \(priceMap.count) days of prices for \(symbol)")
                } else {
                    print("[Migration] Failed to fetch prices for \(symbol)")
                }
            }

            // 获取所有可用的历史日期（从价格数据中提取）
            var allAvailableDates: Set<Date> = []
            for (_, priceMap) in historicalPrices {
                for date in priceMap.keys {
                    allAvailableDates.insert(date)
                }
            }

            // 过滤掉周末
            let calendar = Calendar.current
            let tradingDates = allAvailableDates.filter { date in
                let weekday = calendar.component(.weekday, from: date)
                return weekday != 1 && weekday != 7
            }.sorted()

            print("[Migration] Available trading dates: \(tradingDates.count)")

            // 收集所有需要的货币
            var allCurrencies: Set<String> = [baseCurrency]
            for portfolio in portfolios {
                allCurrencies.insert(portfolio.baseCurrency)
                for holding in portfolio.holdings {
                    allCurrencies.insert(holding.currency)
                }
            }

            // 获取历史汇率数据（1年）
            print("[Migration] Loading historical exchange rates...")
            let historicalRates = await CurrencyService.shared.loadAllHistoricalRates(currencies: allCurrencies)
            print("[Migration] Loaded historical rates for \(historicalRates.count) currency pairs")

            // 辅助函数：获取指定日期的汇率（向前回溯查找）
            func getRateForDate(_ key: String, date: Date) -> Double {
                guard let ratesForPair = historicalRates[key] else { return 1.0 }

                // 尝试获取当天汇率
                if let rate = ratesForPair[date] {
                    return rate
                }

                // 向前回溯最多5天
                var lookbackDate = date
                for _ in 0..<5 {
                    lookbackDate = lookbackDate.adding(days: -1).startOfDay
                    if let rate = ratesForPair[lookbackDate] {
                        return rate
                    }
                }

                // 返回最近的任意汇率
                if let latestRate = ratesForPair.values.first {
                    return latestRate
                }

                return 1.0
            }

            // 为每个账户生成缺失日期的快照
            var createdCount = 0
            for portfolio in portfolios {
                let portfolioID = portfolio.id.uuidString
                let existingDates = existingDatesPerPortfolio[portfolioID] ?? []
                let portfolioCurrency = portfolio.baseCurrency

                for snapshotDate in tradingDates {
                    // 跳过已有快照的日期
                    guard !existingDates.contains(snapshotDate) else { continue }

                    // 获取当天的汇率（账户货币 -> 全局基准货币）
                    let portfolioToBaseRate: Double
                    if portfolioCurrency == baseCurrency {
                        portfolioToBaseRate = 1.0
                    } else {
                        portfolioToBaseRate = getRateForDate("\(portfolioCurrency)\(baseCurrency)", date: snapshotDate)
                    }

                    var portfolioValue: Double = 0
                    var portfolioCost: Double = 0
                    var portfolioDailyPnL: Double = 0

                    for holding in portfolio.holdings {
                        let quantity = holding.quantityAt(date: snapshotDate)
                        guard quantity > 0 else { continue }

                        let cost = holding.totalCostAt(date: snapshotDate)
                        let price = historicalPrices[holding.symbol]?[snapshotDate] ?? 0
                        guard price > 0 else { continue }

                        // 获取当天的汇率（持仓货币 -> 账户货币）
                        let holdingCurrency = holding.currency
                        let holdingToPortfolioRate: Double
                        if holdingCurrency == portfolioCurrency {
                            holdingToPortfolioRate = 1.0
                        } else {
                            holdingToPortfolioRate = getRateForDate("\(holdingCurrency)\(portfolioCurrency)", date: snapshotDate)
                        }

                        let marketValue = quantity * price * holdingToPortfolioRate

                        // 查找前一个交易日的价格（跳过周末和假日）
                        var prevPrice: Double = price
                        var lookbackDate = snapshotDate.adding(days: -1).startOfDay
                        for _ in 0..<5 { // 最多回溯5天
                            if let foundPrice = historicalPrices[holding.symbol]?[lookbackDate] {
                                prevPrice = foundPrice
                                break
                            }
                            lookbackDate = lookbackDate.adding(days: -1).startOfDay
                        }

                        let dailyPnL = quantity * (price - prevPrice) * holdingToPortfolioRate

                        portfolioValue += marketValue
                        portfolioCost += cost * holdingToPortfolioRate
                        portfolioDailyPnL += dailyPnL
                    }

                    // 跳过没有持仓的日期
                    guard portfolioValue > 0 else { continue }

                    let valueInBase = portfolioValue * portfolioToBaseRate
                    let costInBase = portfolioCost * portfolioToBaseRate
                    let dailyPnLInBase = portfolioDailyPnL * portfolioToBaseRate

                    let dailyPnLPercent = (valueInBase - dailyPnLInBase) > 0
                        ? (dailyPnLInBase / (valueInBase - dailyPnLInBase)) * 100
                        : 0

                    let snapshot = DailySnapshot(
                        date: snapshotDate,
                        totalValue: valueInBase,
                        totalCost: costInBase,
                        dailyPnL: dailyPnLInBase,
                        dailyPnLPercent: dailyPnLPercent,
                        cumulativePnL: valueInBase - costInBase,
                        portfolioID: portfolioID
                    )
                    modelContext.insert(snapshot)
                    createdCount += 1
                }
            }

            // 同时生成缺失的全局快照
            let existingGlobalDates = Set(allSnapshots.filter { $0.portfolioID == nil }.map { $0.date.startOfDay })
            var globalCreatedCount = 0

            for snapshotDate in tradingDates {
                guard !existingGlobalDates.contains(snapshotDate) else { continue }

                var globalValue: Double = 0
                var globalCost: Double = 0
                var globalDailyPnL: Double = 0
                var holdingPnLList: [HoldingDailyPnL] = []

                for portfolio in portfolios {
                    let portfolioCurrency = portfolio.baseCurrency

                    // 获取当天的汇率（账户货币 -> 全局基准货币）
                    let portfolioToBaseRate: Double
                    if portfolioCurrency == baseCurrency {
                        portfolioToBaseRate = 1.0
                    } else {
                        portfolioToBaseRate = getRateForDate("\(portfolioCurrency)\(baseCurrency)", date: snapshotDate)
                    }

                    for holding in portfolio.holdings {
                        let quantity = holding.quantityAt(date: snapshotDate)
                        guard quantity > 0 else { continue }

                        let cost = holding.totalCostAt(date: snapshotDate)
                        let price = historicalPrices[holding.symbol]?[snapshotDate] ?? 0
                        guard price > 0 else { continue }

                        // 获取当天的汇率（持仓货币 -> 账户货币）
                        let holdingCurrency = holding.currency
                        let holdingToPortfolioRate: Double
                        if holdingCurrency == portfolioCurrency {
                            holdingToPortfolioRate = 1.0
                        } else {
                            holdingToPortfolioRate = getRateForDate("\(holdingCurrency)\(portfolioCurrency)", date: snapshotDate)
                        }

                        // 组合汇率：持仓货币 -> 账户货币 -> 全局基准货币
                        let holdingToBaseRate = holdingToPortfolioRate * portfolioToBaseRate

                        let marketValue = quantity * price * holdingToBaseRate

                        // 查找前一个交易日的价格
                        var prevPrice: Double = price
                        var lookbackDate = snapshotDate.adding(days: -1).startOfDay
                        for _ in 0..<5 {
                            if let foundPrice = historicalPrices[holding.symbol]?[lookbackDate] {
                                prevPrice = foundPrice
                                break
                            }
                            lookbackDate = lookbackDate.adding(days: -1).startOfDay
                        }

                        let dailyPnL = quantity * (price - prevPrice) * holdingToBaseRate
                        let dailyPnLPercent = prevPrice > 0 ? ((price - prevPrice) / prevPrice) * 100 : 0

                        globalValue += marketValue
                        globalCost += cost * holdingToBaseRate
                        globalDailyPnL += dailyPnL

                        // 收集个股盈亏
                        holdingPnLList.append(HoldingDailyPnL(
                            symbol: holding.symbol,
                            name: holding.name,
                            dailyPnL: dailyPnL,
                            dailyPnLPercent: dailyPnLPercent,
                            marketValue: marketValue
                        ))
                    }
                }

                guard globalValue > 0 else { continue }

                let globalDailyPnLPercent = (globalValue - globalDailyPnL) > 0
                    ? (globalDailyPnL / (globalValue - globalDailyPnL)) * 100
                    : 0

                let globalSnapshot = DailySnapshot(
                    date: snapshotDate,
                    totalValue: globalValue,
                    totalCost: globalCost,
                    dailyPnL: globalDailyPnL,
                    dailyPnLPercent: globalDailyPnLPercent,
                    cumulativePnL: globalValue - globalCost,
                    portfolioID: nil
                )
                globalSnapshot.setHoldingPnLs(holdingPnLList)
                modelContext.insert(globalSnapshot)
                globalCreatedCount += 1
            }

            let totalCreated = createdCount + globalCreatedCount
            if totalCreated > 0 {
                try modelContext.save()
                print("[Migration] Created \(createdCount) portfolio + \(globalCreatedCount) global snapshots")

                // 同步当月数据到 Widget
                syncMonthDataToWidget(modelContext: modelContext)
                WidgetCenter.shared.reloadAllTimelines()
            } else {
                print("[Migration] No new snapshots needed")
            }
        } catch {
            print("[Migration] Failed: \(error)")
        }
    }

    // MARK: - 更新现有快照的个股盈亏数据

    /// 为现有的全局快照补充个股盈亏数据
    func updateSnapshotsWithHoldingPnL(
        portfolios: [Portfolio],
        baseCurrency: String,
        modelContext: ModelContext
    ) async {
        do {
            let allSnapshots = try modelContext.fetch(FetchDescriptor<DailySnapshot>())

            // 找出需要更新的全局快照（没有个股盈亏数据的）
            let snapshotsToUpdate = allSnapshots.filter { snapshot in
                snapshot.portfolioID == nil && snapshot.holdingPnLs.isEmpty
            }

            guard !snapshotsToUpdate.isEmpty else {
                print("[UpdateHoldingPnL] No snapshots need updating")
                return
            }

            print("[UpdateHoldingPnL] Found \(snapshotsToUpdate.count) snapshots to update")

            // 收集所有股票代码
            var allSymbols: Set<String> = []
            var symbolMarkets: [String: Market] = [:]
            for portfolio in portfolios {
                for holding in portfolio.holdings {
                    allSymbols.insert(holding.symbol)
                    symbolMarkets[holding.symbol] = holding.marketEnum
                }
            }

            guard !allSymbols.isEmpty else {
                print("[UpdateHoldingPnL] No holdings found")
                return
            }

            // 获取历史价格
            print("[UpdateHoldingPnL] Fetching historical prices...")
            var historicalPrices: [String: [Date: Double]] = [:]
            for symbol in allSymbols {
                let market = symbolMarkets[symbol] ?? .US
                if market == .JP_FUND { continue }

                if let chartData = try? await MarketDataService.shared.fetchChartData(
                    symbol: symbol,
                    interval: "1d",
                    range: "1y"
                ) {
                    var priceMap: [Date: Double] = [:]
                    for data in chartData {
                        priceMap[data.date.startOfDay] = data.close
                    }
                    historicalPrices[symbol] = priceMap
                }
            }

            // 收集所有需要的货币
            var allCurrencies: Set<String> = [baseCurrency]
            for portfolio in portfolios {
                allCurrencies.insert(portfolio.baseCurrency)
                for holding in portfolio.holdings {
                    allCurrencies.insert(holding.currency)
                }
            }

            // 获取历史汇率
            let historicalRates = await CurrencyService.shared.loadAllHistoricalRates(currencies: allCurrencies)

            // 辅助函数
            func getRateForDate(_ key: String, date: Date) -> Double {
                guard let ratesForPair = historicalRates[key] else { return 1.0 }
                if let rate = ratesForPair[date] { return rate }
                var lookbackDate = date
                for _ in 0..<5 {
                    lookbackDate = lookbackDate.adding(days: -1).startOfDay
                    if let rate = ratesForPair[lookbackDate] { return rate }
                }
                return ratesForPair.values.first ?? 1.0
            }

            // 更新每个快照
            var updatedCount = 0
            for snapshot in snapshotsToUpdate {
                let snapshotDate = snapshot.date.startOfDay
                var holdingPnLList: [HoldingDailyPnL] = []

                for portfolio in portfolios {
                    let portfolioCurrency = portfolio.baseCurrency
                    let portfolioToBaseRate: Double = portfolioCurrency == baseCurrency ? 1.0 :
                        getRateForDate("\(portfolioCurrency)\(baseCurrency)", date: snapshotDate)

                    for holding in portfolio.holdings {
                        let quantity = holding.quantityAt(date: snapshotDate)
                        guard quantity > 0 else { continue }

                        let price = historicalPrices[holding.symbol]?[snapshotDate] ?? 0
                        guard price > 0 else { continue }

                        let holdingCurrency = holding.currency
                        let holdingToPortfolioRate: Double = holdingCurrency == portfolioCurrency ? 1.0 :
                            getRateForDate("\(holdingCurrency)\(portfolioCurrency)", date: snapshotDate)
                        let holdingToBaseRate = holdingToPortfolioRate * portfolioToBaseRate

                        let marketValue = quantity * price * holdingToBaseRate

                        // 查找前一个交易日的价格
                        var prevPrice: Double = price
                        var lookbackDate = snapshotDate.adding(days: -1).startOfDay
                        for _ in 0..<5 {
                            if let foundPrice = historicalPrices[holding.symbol]?[lookbackDate] {
                                prevPrice = foundPrice
                                break
                            }
                            lookbackDate = lookbackDate.adding(days: -1).startOfDay
                        }

                        let dailyPnL = quantity * (price - prevPrice) * holdingToBaseRate
                        let dailyPnLPercent = prevPrice > 0 ? ((price - prevPrice) / prevPrice) * 100 : 0

                        holdingPnLList.append(HoldingDailyPnL(
                            symbol: holding.symbol,
                            name: holding.name,
                            dailyPnL: dailyPnL,
                            dailyPnLPercent: dailyPnLPercent,
                            marketValue: marketValue
                        ))
                    }
                }

                if !holdingPnLList.isEmpty {
                    snapshot.setHoldingPnLs(holdingPnLList)
                    updatedCount += 1
                }
            }

            if updatedCount > 0 {
                try modelContext.save()
                print("[UpdateHoldingPnL] Updated \(updatedCount) snapshots with holding P&L data")
            }
        } catch {
            print("[UpdateHoldingPnL] Failed: \(error)")
        }
    }
}
