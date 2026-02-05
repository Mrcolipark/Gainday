import Foundation
import SwiftData

@Model
class Holding {
    var id: UUID
    var symbol: String
    var name: String
    var assetType: String
    var market: String
    @Relationship(deleteRule: .cascade, inverse: \Transaction.holding)
    var transactions: [Transaction]
    var portfolio: Portfolio?

    init(
        id: UUID = UUID(),
        symbol: String,
        name: String,
        assetType: String = AssetType.stock.rawValue,
        market: String = Market.JP.rawValue,
        transactions: [Transaction] = [],
        portfolio: Portfolio? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.assetType = assetType
        self.market = market
        self.transactions = transactions
        self.portfolio = portfolio
    }

    var assetTypeEnum: AssetType {
        AssetType(rawValue: assetType) ?? .stock
    }

    var marketEnum: Market {
        Market(rawValue: market) ?? .JP
    }

    var totalQuantity: Double {
        transactions.reduce(0) { result, tx in
            let txType = TransactionType(rawValue: tx.type) ?? .buy
            switch txType {
            case .buy:      return result + tx.quantity
            case .sell:     return result - tx.quantity
            case .dividend: return result
            }
        }
    }

    var averageCost: Double {
        var totalCost: Double = 0
        var totalQty: Double = 0
        for tx in transactions.sorted(by: { $0.date < $1.date }) {
            let txType = TransactionType(rawValue: tx.type) ?? .buy
            switch txType {
            case .buy:
                totalCost += tx.quantity * tx.price + tx.fee
                totalQty += tx.quantity
            case .sell:
                if totalQty > 0 {
                    let avgBefore = totalCost / totalQty
                    // 只移除卖出股份的成本，卖出手续费不影响剩余持仓成本
                    totalCost -= tx.quantity * avgBefore
                }
                totalQty -= tx.quantity
            case .dividend:
                break
            }
        }
        return totalQty > 0 ? totalCost / totalQty : 0
    }

    var totalCost: Double {
        averageCost * totalQuantity
    }

    var totalDividends: Double {
        transactions
            .filter { TransactionType(rawValue: $0.type) == .dividend }
            .reduce(0) { $0 + $1.price * $1.quantity }
    }

    /// 已实现盈亏（来自卖出交易）
    var realizedPnL: Double {
        var avgCost: Double = 0
        var totalQty: Double = 0
        var realized: Double = 0

        for tx in transactions.sorted(by: { $0.date < $1.date }) {
            let txType = TransactionType(rawValue: tx.type) ?? .buy
            switch txType {
            case .buy:
                let newCost = tx.quantity * tx.price + tx.fee
                avgCost = totalQty > 0 ? (avgCost * totalQty + newCost) / (totalQty + tx.quantity) : newCost / tx.quantity
                totalQty += tx.quantity
            case .sell:
                if totalQty > 0 {
                    // 卖出收入 - 卖出成本 - 卖出手续费 = 已实现盈亏
                    let sellProceeds = tx.quantity * tx.price
                    let sellCostBasis = tx.quantity * avgCost
                    realized += sellProceeds - sellCostBasis - tx.fee
                }
                totalQty -= tx.quantity
            case .dividend:
                break
            }
        }
        return realized
    }

    /// 总卖出手续费
    var totalSellFees: Double {
        transactions
            .filter { TransactionType(rawValue: $0.type) == .sell }
            .reduce(0) { $0 + $1.fee }
    }

    var currency: String {
        marketEnum.currency
    }
}
