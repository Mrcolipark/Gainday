import Foundation
import SwiftUI
import SwiftData

@Observable
@MainActor
class HomeViewModel {
    var quotes: [String: MarketDataService.QuoteData] = [:]
    var portfolioPnLs: [PnLCalculationService.PortfolioPnL] = []
    var overallPnL: PnLCalculationService.OverallPnL?
    var displayMode: PortfolioDisplayMode = .basic
    var showPercentChange = true
    var isLoading = false
    var expandedPortfolios: Set<String> = []
    var lastRefreshTime: Date?
    var refreshError: Error?

    // 存储汇率供快照使用
    private var cachedRates: [String: Double] = [:]

    /// 数据是否过期（超过5分钟）
    var isDataStale: Bool {
        guard let lastRefresh = lastRefreshTime else { return true }
        return Date().timeIntervalSince(lastRefresh) > 300
    }

    /// 格式化的最后更新时间
    var lastRefreshTimeFormatted: String? {
        guard let time = lastRefreshTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }

    var totalValue: Double {
        overallPnL?.totalValue ?? 0
    }

    var dailyPnL: Double {
        overallPnL?.dailyPnL ?? 0
    }

    var dailyPnLPercent: Double {
        overallPnL?.dailyPnLPercent ?? 0
    }

    var unrealizedPnL: Double {
        overallPnL?.unrealizedPnL ?? 0
    }

    var unrealizedPnLPercent: Double {
        overallPnL?.unrealizedPnLPercent ?? 0
    }

    func togglePortfolioExpansion(_ id: String) {
        if expandedPortfolios.contains(id) {
            expandedPortfolios.remove(id)
        } else {
            expandedPortfolios.insert(id)
        }
    }

    func isPortfolioExpanded(_ id: String) -> Bool {
        expandedPortfolios.contains(id)
    }

    func refreshAll(portfolios: [Portfolio], baseCurrency: String = "JPY", modelContext: ModelContext? = nil) async {
        isLoading = true
        refreshError = nil
        defer { isLoading = false }

        let allSymbols = portfolios.flatMap(\.holdings).map(\.symbol)

        // 即使没有持仓也要生成空的 portfolioPnLs，避免显示备用界面
        if allSymbols.isEmpty {
            var pnls: [PnLCalculationService.PortfolioPnL] = []
            for portfolio in portfolios {
                let emptyPnL = PnLCalculationService.PortfolioPnL(
                    portfolio: portfolio,
                    totalValue: 0,
                    totalCost: 0,
                    totalUnrealizedPnL: 0,
                    totalUnrealizedPnLPercent: 0,
                    dailyPnL: 0,
                    dailyPnLPercent: 0,
                    holdingPnLs: []
                )
                pnls.append(emptyPnL)
            }
            portfolioPnLs = pnls
            overallPnL = PnLCalculationService.OverallPnL(
                totalValue: 0,
                totalCost: 0,
                unrealizedPnL: 0,
                unrealizedPnLPercent: 0,
                dailyPnL: 0,
                dailyPnLPercent: 0,
                portfolioPnLs: pnls
            )
            // Auto-expand all portfolios
            for portfolio in portfolios {
                expandedPortfolios.insert(portfolio.id.uuidString)
            }
            lastRefreshTime = Date()
            return
        }

        do {
            // 1. 获取所有持仓的报价（区分普通股票和日本投信）
            let holdings = portfolios.flatMap(\.holdings)
            let holdingMarkets = holdings.map { ($0.symbol, Market(rawValue: $0.market) ?? .JP) }

            let quoteResults = try await MarketDataService.shared.fetchUnifiedQuotes(holdings: holdingMarkets)
            quotes = quoteResults

            // 2. 获取汇率（如果有多币种）
            let currencies = Set(portfolios.map(\.baseCurrency))
            var rates: [String: Double] = [:]
            if currencies.count > 1 {
                // 获取所有货币对 JPY 的汇率
                for currency in currencies where currency != "JPY" {
                    if let rate = try? await CurrencyService.shared.getRate(from: currency, to: "JPY") {
                        rates["\(currency)_JPY"] = rate
                    }
                }
            }

            // 3. 计算各账户盈亏
            let calcService = PnLCalculationService.shared
            var pnls: [PnLCalculationService.PortfolioPnL] = []

            var totalValue: Double = 0
            var totalCost: Double = 0
            var totalDailyPnL: Double = 0

            for portfolio in portfolios {
                let pnl = calcService.calculatePortfolioPnL(
                    portfolio: portfolio,
                    quotes: quotes,
                    rates: rates
                )
                pnls.append(pnl)
                totalValue += pnl.totalValue
                totalCost += pnl.totalCost
                totalDailyPnL += pnl.dailyPnL
            }

            portfolioPnLs = pnls

            let unrealized = totalValue - totalCost
            let unrealizedPct = totalCost > 0 ? (unrealized / totalCost) * 100 : 0
            let previousValue = totalValue - totalDailyPnL
            let dailyPct = previousValue > 0 ? (totalDailyPnL / previousValue) * 100 : 0

            overallPnL = PnLCalculationService.OverallPnL(
                totalValue: totalValue,
                totalCost: totalCost,
                unrealizedPnL: unrealized,
                unrealizedPnLPercent: unrealizedPct,
                dailyPnL: totalDailyPnL,
                dailyPnLPercent: dailyPct,
                portfolioPnLs: pnls
            )

            // Auto-expand all portfolios on first load
            if expandedPortfolios.isEmpty {
                for portfolio in portfolios {
                    expandedPortfolios.insert(portfolio.id.uuidString)
                }
            }

            // 缓存汇率
            cachedRates = rates

            // 更新刷新时间
            lastRefreshTime = Date()

            // 自动生成/更新今日快照
            if let context = modelContext {
                await SnapshotService.shared.saveOrUpdateTodaySnapshot(
                    portfolios: portfolios,
                    quotes: quotes,
                    rates: rates,
                    baseCurrency: baseCurrency,
                    modelContext: context
                )
            }
        } catch {
            refreshError = error
            ErrorPresenter.shared.showError(error)
        }
    }
}
