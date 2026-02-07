import Foundation
import SwiftData
import SwiftUI

@Model
class Portfolio {
    var id: UUID
    var name: String
    var accountType: String
    var baseCurrency: String
    var sortOrder: Int
    var colorTag: String
    @Relationship(deleteRule: .cascade, inverse: \Holding.portfolio)
    var holdings: [Holding]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        accountType: String = AccountType.general.rawValue,
        baseCurrency: String = BaseCurrency.JPY.rawValue,
        sortOrder: Int = 0,
        colorTag: String = "blue",
        holdings: [Holding] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.accountType = accountType
        self.baseCurrency = baseCurrency
        self.sortOrder = sortOrder
        self.colorTag = colorTag
        self.holdings = holdings
        self.createdAt = createdAt
    }

    var accountTypeEnum: AccountType {
        // 处理旧数据中的 "normal" 值
        if accountType == "normal" {
            return .general
        }
        return AccountType(rawValue: accountType) ?? .general
    }

    var baseCurrencyEnum: BaseCurrency {
        BaseCurrency(rawValue: baseCurrency) ?? .JPY
    }

    var tagColor: Color {
        switch colorTag {
        case "blue":   return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "teal":   return .teal
        case "pink":   return .pink
        case "indigo": return .indigo
        default:       return .blue
        }
    }

    // MARK: - Account Type Helpers

    /// 该账户允许的市场列表
    var allowedMarkets: [Market] {
        accountTypeEnum.allowedMarkets
    }

    /// 是否为 NISA 账户
    var isNISA: Bool {
        accountTypeEnum.isNISA
    }

    /// 是否可以更改账户类型
    /// 有持仓时不允许更改账户类型，以避免数据不一致
    var canChangeAccountType: Bool {
        holdings.isEmpty
    }
}
