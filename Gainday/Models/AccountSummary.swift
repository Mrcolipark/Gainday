import Foundation
import SwiftUI

/// 账户汇总模型 - 用于按账户类型聚合持仓数据
struct AccountSummary: Identifiable {
    let id = UUID()
    let accountType: AccountType
    let holdings: [Holding]

    /// 总市值（需要传入报价数据计算）
    /// 注意：此方法返回原币种的总市值，不进行汇率转换
    func totalValue(quotes: [String: MarketDataService.QuoteData]) -> Double {
        holdings.reduce(0) { total, holding in
            guard let quote = quotes[holding.symbol],
                  let price = quote.regularMarketPrice else { return total }
            return total + holding.totalQuantity * price
        }
    }

    /// 已使用的年度额度（今年的买入总额）
    var usedAnnualLimit: Double {
        let currentYear = Calendar.current.component(.year, from: Date())
        return holdings.flatMap(\.transactions).reduce(0) { total, tx in
            let txYear = Calendar.current.component(.year, from: tx.date)
            guard txYear == currentYear,
                  TransactionType(rawValue: tx.type) == .buy else { return total }
            return total + tx.quantity * tx.price
        }
    }

    /// 已使用的生涯额度
    /// NISA 规则：卖出后，簿価（取得価額）在翌年复活
    /// 当年卖出的部分仍算已使用；前年以前卖出的已复活
    var usedLifetimeLimit: Double {
        let currentYear = Calendar.current.component(.year, from: Date())
        // 所有买入总额
        let totalBought = holdings.flatMap(\.transactions).reduce(0.0) { total, tx in
            guard TransactionType(rawValue: tx.type) == .buy else { return total }
            return total + tx.quantity * tx.price
        }
        // 前年以前卖出的总额（已复活的额度）
        let recoveredFromPriorYears = holdings.flatMap(\.transactions).reduce(0.0) { total, tx in
            let txYear = Calendar.current.component(.year, from: tx.date)
            guard TransactionType(rawValue: tx.type) == .sell,
                  txYear < currentYear else { return total }
            return total + tx.quantity * tx.price
        }
        return max(0, totalBought - recoveredFromPriorYears)
    }

    /// 年度剩余额度
    var remainingAnnualLimit: Double? {
        guard let limit = accountType.annualLimit else { return nil }
        return max(0, limit - usedAnnualLimit)
    }

    /// 年度额度使用比例 (0-1)
    var annualUsageRatio: Double? {
        guard let limit = accountType.annualLimit else { return nil }
        return min(1.0, usedAnnualLimit / limit)
    }

    /// 生涯额度使用比例 (0-1) - 针对 NISA 整体
    var lifetimeUsageRatio: Double {
        min(1.0, usedLifetimeLimit / AccountType.lifetimeLimit)
    }

    /// 持仓数量
    var holdingCount: Int {
        holdings.count
    }

    /// 是否有持仓
    var hasHoldings: Bool {
        !holdings.isEmpty
    }

    /// 是否为 NISA 账户
    var isNISA: Bool {
        accountType.isNISA
    }
}

// MARK: - NISA 额度计算器

struct NISAQuotaCalculator {

    /// 计算 NISA 总体额度使用情况
    static func calculateOverall(holdings: [Holding]) -> NISAOverallQuota {
        let nisaHoldings = holdings.filter { $0.isNISA }

        let tsumitateHoldings = nisaHoldings.filter { $0.accountTypeEnum == .nisa_tsumitate }
        let growthHoldings = nisaHoldings.filter { $0.accountTypeEnum == .nisa_growth }

        let currentYear = Calendar.current.component(.year, from: Date())

        // 年度使用额度
        let tsumitateAnnualUsed = calculateAnnualUsed(holdings: tsumitateHoldings, year: currentYear)
        let growthAnnualUsed = calculateAnnualUsed(holdings: growthHoldings, year: currentYear)

        // 生涯使用额度（买入总额 - 前年以前卖出的复活额度）
        let tsumitateLifetimeUsed = calculateLifetimeUsed(holdings: tsumitateHoldings, currentYear: currentYear)
        let growthLifetimeUsed = calculateLifetimeUsed(holdings: growthHoldings, currentYear: currentYear)

        return NISAOverallQuota(
            tsumitateAnnualUsed: tsumitateAnnualUsed,
            growthAnnualUsed: growthAnnualUsed,
            tsumitateLifetimeUsed: tsumitateLifetimeUsed,
            growthLifetimeUsed: growthLifetimeUsed,
            year: currentYear
        )
    }

    private static func calculateAnnualUsed(holdings: [Holding], year: Int) -> Double {
        holdings.flatMap(\.transactions).reduce(0) { total, tx in
            let txYear = Calendar.current.component(.year, from: tx.date)
            guard txYear == year,
                  TransactionType(rawValue: tx.type) == .buy else { return total }
            return total + tx.quantity * tx.price
        }
    }

    /// 生涯使用额度 = 全買入总額 - 前年以前卖出的復活額
    private static func calculateLifetimeUsed(holdings: [Holding], currentYear: Int) -> Double {
        let allTx = holdings.flatMap(\.transactions)
        let totalBought = allTx.reduce(0.0) { total, tx in
            guard TransactionType(rawValue: tx.type) == .buy else { return total }
            return total + tx.quantity * tx.price
        }
        let recoveredFromPriorYears = allTx.reduce(0.0) { total, tx in
            let txYear = Calendar.current.component(.year, from: tx.date)
            guard TransactionType(rawValue: tx.type) == .sell,
                  txYear < currentYear else { return total }
            return total + tx.quantity * tx.price
        }
        return max(0, totalBought - recoveredFromPriorYears)
    }
}

/// NISA 整体额度信息
struct NISAOverallQuota {
    let tsumitateAnnualUsed: Double   // つみたて枠年度已用
    let growthAnnualUsed: Double      // 成長枠年度已用
    let tsumitateLifetimeUsed: Double // つみたて枠生涯已用
    let growthLifetimeUsed: Double    // 成長枠生涯已用
    let year: Int                     // 年度

    // MARK: - 年度额度

    var tsumitateAnnualLimit: Double { 120 * 10000 }  // 120万円
    var growthAnnualLimit: Double { 240 * 10000 }     // 240万円
    var totalAnnualLimit: Double { 360 * 10000 }      // 360万円

    var tsumitateAnnualRemaining: Double {
        max(0, tsumitateAnnualLimit - tsumitateAnnualUsed)
    }

    var growthAnnualRemaining: Double {
        max(0, growthAnnualLimit - growthAnnualUsed)
    }

    var totalAnnualUsed: Double {
        tsumitateAnnualUsed + growthAnnualUsed
    }

    var totalAnnualRemaining: Double {
        max(0, totalAnnualLimit - totalAnnualUsed)
    }

    // MARK: - 生涯额度

    var lifetimeLimit: Double { AccountType.lifetimeLimit }       // 1800万円
    var growthLifetimeLimit: Double { AccountType.growthLifetimeLimit }  // 成長枠上限 1200万円

    var totalLifetimeUsed: Double {
        tsumitateLifetimeUsed + growthLifetimeUsed
    }

    var lifetimeRemaining: Double {
        max(0, lifetimeLimit - totalLifetimeUsed)
    }

    // MARK: - 比例

    var tsumitateAnnualRatio: Double {
        min(1.0, tsumitateAnnualUsed / tsumitateAnnualLimit)
    }

    var growthAnnualRatio: Double {
        min(1.0, growthAnnualUsed / growthAnnualLimit)
    }

    var lifetimeRatio: Double {
        min(1.0, totalLifetimeUsed / lifetimeLimit)
    }

    // MARK: - 格式化

    func formatManYen(_ value: Double) -> String {
        let manYen = value / 10000
        if manYen >= 100 {
            return String(format: "%.0f万", manYen)
        } else if manYen >= 1 {
            return String(format: "%.1f万", manYen)
        } else {
            return String(format: "%.0f円", value)
        }
    }
}
