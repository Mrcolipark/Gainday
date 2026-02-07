import Foundation
import SwiftUI

// MARK: - Asset Type

enum AssetType: String, Codable, CaseIterable, Identifiable {
    case stock
    case fund
    case metal
    case crypto
    case bond
    case cash

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stock:  return "股票".localized
        case .fund:   return "基金".localized
        case .metal:  return "贵金属".localized
        case .crypto: return "加密货币".localized
        case .bond:   return "债券".localized
        case .cash:   return "现金".localized
        }
    }

    var iconName: String {
        switch self {
        case .stock:  return "chart.line.uptrend.xyaxis"
        case .fund:   return "chart.pie.fill"
        case .metal:  return "diamond.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        case .bond:   return "doc.text.fill"
        case .cash:   return "banknote.fill"
        }
    }

    var color: Color {
        switch self {
        case .stock:  return .blue
        case .fund:   return .purple
        case .metal:  return .orange
        case .crypto: return .yellow
        case .bond:   return .teal
        case .cash:   return .green
        }
    }
}

// MARK: - Market

enum Market: String, Codable, CaseIterable, Identifiable {
    case JP
    case JP_FUND  // 日本投資信託
    case CN
    case US
    case HK
    case COMMODITY
    case CRYPTO

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .JP:        return "日本股票".localized
        case .JP_FUND:   return "日本投信".localized
        case .CN:        return "中国A股".localized
        case .US:        return "美国".localized
        case .HK:        return "香港".localized
        case .COMMODITY: return "大宗商品".localized
        case .CRYPTO:    return "加密货币".localized
        }
    }

    var flag: String {
        switch self {
        case .JP:        return "🇯🇵"
        case .JP_FUND:   return "🇯🇵"
        case .CN:        return "🇨🇳"
        case .US:        return "🇺🇸"
        case .HK:        return "🇭🇰"
        case .COMMODITY: return "🏆"
        case .CRYPTO:    return "🪙"
        }
    }

    var currency: String {
        switch self {
        case .JP:        return "JPY"
        case .JP_FUND:   return "JPY"
        case .CN:        return "CNY"
        case .US:        return "USD"
        case .HK:        return "HKD"
        case .COMMODITY: return "USD"
        case .CRYPTO:    return "USD"
        }
    }

    /// 是否使用Yahoo Finance API (false = 使用JapanFundService)
    var usesYahooFinance: Bool {
        switch self {
        case .JP_FUND: return false
        default: return true
        }
    }
}

// MARK: - Transaction Type

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case buy
    case sell
    case dividend

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .buy:      return "买入".localized
        case .sell:     return "卖出".localized
        case .dividend: return "分红".localized
        }
    }

    var iconName: String {
        switch self {
        case .buy:      return "arrow.down.circle.fill"
        case .sell:     return "arrow.up.circle.fill"
        case .dividend: return "banknote.fill"
        }
    }

    var color: Color {
        switch self {
        case .buy:      return .blue
        case .sell:     return .orange
        case .dividend: return .green
        }
    }
}

// MARK: - Account Type

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case normal
    case nisa_tsumitate
    case nisa_growth

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal:         return "普通账户".localized
        case .nisa_tsumitate: return "NISA つみたて"
        case .nisa_growth:    return "NISA 成長"
        }
    }

    var iconName: String {
        switch self {
        case .normal:         return "building.columns.fill"
        case .nisa_tsumitate: return "shield.checkered"
        case .nisa_growth:    return "shield.checkered"
        }
    }
}

// MARK: - Market State

enum MarketState: String, Codable {
    case pre = "PRE"
    case regular = "REGULAR"
    case post = "POST"
    case closed = "CLOSED"
    case prepre = "PREPRE"
    case postpost = "POSTPOST"

    var displayName: String {
        switch self {
        case .pre:      return "盘前".localized
        case .regular:  return "交易中".localized
        case .post:     return "盘后".localized
        case .closed:   return "收盘".localized
        case .prepre:   return "盘前".localized
        case .postpost: return "盘后".localized
        }
    }

    var color: Color {
        switch self {
        case .pre, .prepre:   return .orange
        case .regular:        return .green
        case .post, .postpost: return .purple
        case .closed:         return .secondary
        }
    }

    var isTrading: Bool {
        switch self {
        case .pre, .regular, .post, .prepre, .postpost: return true
        case .closed: return false
        }
    }
}

// MARK: - Base Currency

enum BaseCurrency: String, Codable, CaseIterable, Identifiable {
    case JPY
    case CNY
    case USD
    case HKD

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .JPY: return "¥"
        case .CNY: return "¥"
        case .USD: return "$"
        case .HKD: return "HK$"
        }
    }

    var displayName: String {
        switch self {
        case .JPY: return "日元 (JPY)".localized
        case .CNY: return "人民币 (CNY)".localized
        case .USD: return "美元 (USD)".localized
        case .HKD: return "港元 (HKD)".localized
        }
    }
}

// MARK: - Portfolio Display Mode

enum PortfolioDisplayMode: String, CaseIterable, Identifiable {
    case basic
    case details
    case holdings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .basic:    return "列表".localized
        case .details:  return "详情".localized
        case .holdings: return "持仓".localized
        }
    }

    var iconName: String {
        switch self {
        case .basic:    return "list.bullet"
        case .details:  return "list.bullet.indent"
        case .holdings: return "chart.bar.doc.horizontal"
        }
    }
}

// MARK: - Time Range

enum TimeRange: String, CaseIterable, Identifiable {
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "1Y"
    case all = "ALL"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var days: Int? {
        switch self {
        case .week:        return 7
        case .month:       return 30
        case .threeMonths: return 90
        case .sixMonths:   return 180
        case .year:        return 365
        case .all:         return nil
        }
    }
}
