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

            // 2. 获取汇率（收集所有持仓的货币，换算到各账户的基准货币）
            var rates: [String: Double] = [:]

            for portfolio in portfolios {
                let portfolioBaseCurrency = portfolio.baseCurrency

                // 收集该账户下所有持仓的货币
                let holdingCurrencies = Set(portfolio.holdings.compactMap { holding -> String? in
                    // 从报价获取货币，或根据市场推断
                    if let quote = quoteResults[holding.symbol], let currency = quote.currency {
                        return currency
                    }
                    // 根据市场推断货币
                    switch Market(rawValue: holding.market) {
                    case .US: return "USD"
                    case .JP, .JP_FUND: return "JPY"
                    case .CN: return "CNY"
                    case .HK: return "HKD"
                    default: return nil
                    }
                })

                // 获取每种持仓货币到账户基准货币的汇率
                for holdingCurrency in holdingCurrencies where holdingCurrency != portfolioBaseCurrency {
                    let rateKey = "\(holdingCurrency)\(portfolioBaseCurrency)"
                    if rates[rateKey] == nil {
                        if let rate = try? await CurrencyService.shared.getRate(from: holdingCurrency, to: portfolioBaseCurrency) {
                            rates[rateKey] = rate
                        }
                    }
                }
            }

            // 3. 计算各账户盈亏
            let calcService = PnLCalculationService.shared
            var pnls: [PnLCalculationService.PortfolioPnL] = []

            // 全局基准货币的汇总（需要把各账户的值换算到全局基准货币）
            var totalValueInBase: Double = 0
            var totalCostInBase: Double = 0
            var totalDailyPnLInBase: Double = 0

            for portfolio in portfolios {
                let pnl = calcService.calculatePortfolioPnL(
                    portfolio: portfolio,
                    quotes: quotes,
                    rates: rates
                )
                pnls.append(pnl)

                // 把账户基准货币换算到全局基准货币
                let portfolioBaseCurrency = portfolio.baseCurrency
                var portfolioToGlobalRate: Double = 1.0

                if portfolioBaseCurrency != baseCurrency {
                    // 获取账户基准货币到全局基准货币的汇率
                    let rateKey = "\(portfolioBaseCurrency)\(baseCurrency)"
                    if let rate = rates[rateKey] {
                        portfolioToGlobalRate = rate
                    } else if let rate = try? await CurrencyService.shared.getRate(from: portfolioBaseCurrency, to: baseCurrency) {
                        portfolioToGlobalRate = rate
                        rates[rateKey] = rate  // 缓存
                    }
                }

                totalValueInBase += pnl.totalValue * portfolioToGlobalRate
                totalCostInBase += pnl.totalCost * portfolioToGlobalRate
                totalDailyPnLInBase += pnl.dailyPnL * portfolioToGlobalRate
            }

            portfolioPnLs = pnls

            let unrealized = totalValueInBase - totalCostInBase
            let unrealizedPct = totalCostInBase > 0 ? (unrealized / totalCostInBase) * 100 : 0
            let previousValue = totalValueInBase - totalDailyPnLInBase
            let dailyPct = previousValue > 0 ? (totalDailyPnLInBase / previousValue) * 100 : 0

            overallPnL = PnLCalculationService.OverallPnL(
                totalValue: totalValueInBase,
                totalCost: totalCostInBase,
                unrealizedPnL: unrealized,
                unrealizedPnLPercent: unrealizedPct,
                dailyPnL: totalDailyPnLInBase,
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
