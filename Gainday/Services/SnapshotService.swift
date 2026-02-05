import Foundation
import SwiftData

actor SnapshotService {
    static let shared = SnapshotService()

    private init() {}

    func generateDailySnapshot(
        portfolios: [Portfolio],
        quotes: [String: MarketDataService.QuoteData],
        rates: [String: Double],
        baseCurrency: String,
        modelContext: ModelContext
    ) async -> DailySnapshot {
        let today = Date().startOfDay
        let calcService = PnLCalculationService.shared

        var totalValue: Double = 0
        var totalCost: Double = 0
        var dailyPnL: Double = 0
        var breakdownItems: [AssetBreakdown] = []

        var assetTypeValues: [String: (value: Double, cost: Double, pnl: Double)] = [:]

        for portfolio in portfolios {
            let portfolioPnL = calcService.calculatePortfolioPnL(
                portfolio: portfolio,
                quotes: quotes,
                rates: rates
            )

            let portfolioCurrency = portfolio.baseCurrency
            let portfolioRate = rates["\(portfolioCurrency)\(baseCurrency)"] ?? 1.0

            totalValue += portfolioPnL.totalValue * portfolioRate
            totalCost += portfolioPnL.totalCost * portfolioRate
            dailyPnL += portfolioPnL.dailyPnL * portfolioRate

            for hpnl in portfolioPnL.holdingPnLs {
                let assetType = hpnl.holding.assetType
                var existing = assetTypeValues[assetType] ?? (value: 0, cost: 0, pnl: 0)
                existing.value += hpnl.marketValue * portfolioRate
                existing.cost += hpnl.costBasis * portfolioRate
                existing.pnl += hpnl.dailyPnL * portfolioRate
                assetTypeValues[assetType] = existing
            }
        }

        for (assetType, values) in assetTypeValues {
            breakdownItems.append(AssetBreakdown(
                assetType: assetType,
                value: values.value,
                cost: values.cost,
                pnl: values.pnl,
                currency: baseCurrency
            ))
        }

        let dailyPnLPercent = (totalValue - dailyPnL) > 0
            ? (dailyPnL / (totalValue - dailyPnL)) * 100
            : 0
        let cumulativePnL = totalValue - totalCost

        let snapshot = DailySnapshot(
            date: today,
            totalValue: totalValue,
            totalCost: totalCost,
            dailyPnL: dailyPnL,
            dailyPnLPercent: dailyPnLPercent,
            cumulativePnL: cumulativePnL
        )
        snapshot.setBreakdown(breakdownItems)

        return snapshot
    }

    func fetchSnapshots(
        for month: Date,
        modelContext: ModelContext
    ) throws -> [DailySnapshot] {
        let startOfMonth = month.startOfMonth
        let endOfMonth = month.endOfMonth.adding(days: 1)

        let predicate = #Predicate<DailySnapshot> {
            $0.date >= startOfMonth && $0.date < endOfMonth
        }
        let descriptor = FetchDescriptor<DailySnapshot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )

        return try modelContext.fetch(descriptor)
    }

    func fetchSnapshots(
        from startDate: Date,
        to endDate: Date,
        modelContext: ModelContext
    ) throws -> [DailySnapshot] {
        let start = startDate.startOfDay
        let end = endDate.adding(days: 1).startOfDay

        let predicate = #Predicate<DailySnapshot> {
            $0.date >= start && $0.date < end
        }
        let descriptor = FetchDescriptor<DailySnapshot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )

        return try modelContext.fetch(descriptor)
    }

    func snapshotExists(for date: Date, modelContext: ModelContext) throws -> Bool {
        let dayStart = date.startOfDay
        let dayEnd = date.adding(days: 1).startOfDay

        let predicate = #Predicate<DailySnapshot> {
            $0.date >= dayStart && $0.date < dayEnd
        }
        var descriptor = FetchDescriptor<DailySnapshot>(predicate: predicate)
        descriptor.fetchLimit = 1

        let count = try modelContext.fetchCount(descriptor)
        return count > 0
    }

    // MARK: - Auto-generate Today's Snapshot

    /// 检查并生成今日快照（如果不存在或需要更新）
    /// 在每次刷新数据后调用
    @MainActor
    func saveOrUpdateTodaySnapshot(
        portfolios: [Portfolio],
        quotes: [String: MarketDataService.QuoteData],
        rates: [String: Double],
        baseCurrency: String,
        modelContext: ModelContext
    ) async {
        let today = Date().startOfDay

        // 如果是周末，跳过
        let weekday = Calendar.current.component(.weekday, from: today)
        if weekday == 1 || weekday == 7 { return }

        // 如果没有持仓，跳过
        let hasHoldings = portfolios.contains { !$0.holdings.isEmpty }
        guard hasHoldings else { return }

        // 生成新快照
        let newSnapshot = await generateDailySnapshot(
            portfolios: portfolios,
            quotes: quotes,
            rates: rates,
            baseCurrency: baseCurrency,
            modelContext: modelContext
        )

        // 检查今日是否已有快照
        do {
            let dayStart = today
            let dayEnd = today.adding(days: 1)

            let predicate = #Predicate<DailySnapshot> {
                $0.date >= dayStart && $0.date < dayEnd
            }
            var descriptor = FetchDescriptor<DailySnapshot>(predicate: predicate)
            descriptor.fetchLimit = 1

            let existing = try modelContext.fetch(descriptor)

            if let existingSnapshot = existing.first {
                // 更新现有快照
                existingSnapshot.totalValue = newSnapshot.totalValue
                existingSnapshot.totalCost = newSnapshot.totalCost
                existingSnapshot.dailyPnL = newSnapshot.dailyPnL
                existingSnapshot.dailyPnLPercent = newSnapshot.dailyPnLPercent
                existingSnapshot.cumulativePnL = newSnapshot.cumulativePnL
                existingSnapshot.breakdownJSON = newSnapshot.breakdownJSON
            } else {
                // 插入新快照
                modelContext.insert(newSnapshot)
            }

            try modelContext.save()
        } catch {
            // 静默失败，不影响用户体验
            print("Failed to save snapshot: \(error)")
        }
    }

    /// 获取最近一个交易日的快照
    func getLatestSnapshot(modelContext: ModelContext) throws -> DailySnapshot? {
        var descriptor = FetchDescriptor<DailySnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// 获取年度所有快照（用于年度热力图）
    func fetchYearSnapshots(year: Int, modelContext: ModelContext) throws -> [DailySnapshot] {
        let calendar = Calendar.current
        guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return []
        }

        let predicate = #Predicate<DailySnapshot> {
            $0.date >= startOfYear && $0.date < endOfYear
        }
        let descriptor = FetchDescriptor<DailySnapshot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )

        return try modelContext.fetch(descriptor)
    }
}
