import Foundation
import SwiftData

@Observable
class PnLCalculationService {
    static let shared = PnLCalculationService()

    private init() {}

    struct HoldingPnL {
        let holding: Holding
        let currentPrice: Double
        let previousClose: Double
        let marketValue: Double
        let costBasis: Double
        let unrealizedPnL: Double
        let unrealizedPnLPercent: Double
        let dailyPnL: Double
        let dailyPnLPercent: Double
        let marketState: MarketState?
        let effectivePrice: Double
    }

    struct PortfolioPnL {
        let portfolio: Portfolio
        let totalValue: Double
        let totalCost: Double
        let totalUnrealizedPnL: Double
        let totalUnrealizedPnLPercent: Double
        let dailyPnL: Double
        let dailyPnLPercent: Double
        let holdingPnLs: [HoldingPnL]
    }

    struct OverallPnL {
        let totalValue: Double
        let totalCost: Double
        let unrealizedPnL: Double
        let unrealizedPnLPercent: Double
        let dailyPnL: Double
        let dailyPnLPercent: Double
        let portfolioPnLs: [PortfolioPnL]
    }

    func calculateHoldingPnL(
        holding: Holding,
        quote: MarketDataService.QuoteData?,
        exchangeRate: Double = 1.0
    ) -> HoldingPnL {
        let qty = holding.totalQuantity
        let avgCost = holding.averageCost
        let costBasis = avgCost * qty

        let currentPrice = quote?.regularMarketPrice ?? 0
        let previousClose = quote?.regularMarketPreviousClose ?? currentPrice

        let mktState: MarketState?
        if let stateStr = quote?.marketState {
            mktState = MarketState(rawValue: stateStr)
        } else {
            mktState = nil
        }

        let effectivePrice: Double
        switch mktState {
        case .pre, .prepre:
            effectivePrice = quote?.preMarketPrice ?? currentPrice
        case .post, .postpost:
            effectivePrice = quote?.postMarketPrice ?? currentPrice
        default:
            effectivePrice = currentPrice
        }

        let marketValue = effectivePrice * qty * exchangeRate
        let costInBase = costBasis * exchangeRate
        let unrealizedPnL = marketValue - costInBase
        let unrealizedPnLPercent = costInBase > 0 ? (unrealizedPnL / costInBase) * 100 : 0

        let dailyPnL = (effectivePrice - previousClose) * qty * exchangeRate
        let previousValue = previousClose * qty * exchangeRate
        let dailyPnLPercent = previousValue > 0 ? (dailyPnL / previousValue) * 100 : 0

        return HoldingPnL(
            holding: holding,
            currentPrice: currentPrice,
            previousClose: previousClose,
            marketValue: marketValue,
            costBasis: costInBase,
            unrealizedPnL: unrealizedPnL,
            unrealizedPnLPercent: unrealizedPnLPercent,
            dailyPnL: dailyPnL,
            dailyPnLPercent: dailyPnLPercent,
            marketState: mktState,
            effectivePrice: effectivePrice
        )
    }

    func calculatePortfolioPnL(
        portfolio: Portfolio,
        quotes: [String: MarketDataService.QuoteData],
        rates: [String: Double]
    ) -> PortfolioPnL {
        let baseCurrency = portfolio.baseCurrency

        let holdingPnLs = portfolio.holdings.map { holding in
            let quote = quotes[holding.symbol]
            let holdingCurrency = holding.currency
            let rate = rates["\(holdingCurrency)\(baseCurrency)"] ?? 1.0
            return calculateHoldingPnL(holding: holding, quote: quote, exchangeRate: rate)
        }

        let totalValue = holdingPnLs.reduce(0) { $0 + $1.marketValue }
        let totalCost = holdingPnLs.reduce(0) { $0 + $1.costBasis }
        let totalUnrealizedPnL = totalValue - totalCost
        let totalUnrealizedPnLPercent = totalCost > 0 ? (totalUnrealizedPnL / totalCost) * 100 : 0
        let dailyPnL = holdingPnLs.reduce(0) { $0 + $1.dailyPnL }
        let previousTotalValue = totalValue - dailyPnL
        let dailyPnLPercent = previousTotalValue > 0 ? (dailyPnL / previousTotalValue) * 100 : 0

        return PortfolioPnL(
            portfolio: portfolio,
            totalValue: totalValue,
            totalCost: totalCost,
            totalUnrealizedPnL: totalUnrealizedPnL,
            totalUnrealizedPnLPercent: totalUnrealizedPnLPercent,
            dailyPnL: dailyPnL,
            dailyPnLPercent: dailyPnLPercent,
            holdingPnLs: holdingPnLs
        )
    }
}
