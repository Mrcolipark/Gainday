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
    case general = "general"           // 一般账户（普通/特定）
    case nisa_tsumitate               // つみたて投資枠
    case nisa_growth                  // 成長投資枠

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: return "普通账户".localized
        case .nisa_tsumitate:   return "NISA つみたて枠".localized
        case .nisa_growth:      return "NISA 成長枠".localized
        }
    }

    var shortName: String {
        switch self {
        case .general: return "一般".localized
        case .nisa_tsumitate:   return "つみたて"
        case .nisa_growth:      return "成長"
        }
    }

    var iconName: String {
        switch self {
        case .general: return "building.columns.fill"
        case .nisa_tsumitate:   return "leaf.fill"
        case .nisa_growth:      return "chart.line.uptrend.xyaxis"
        }
    }

    var isNISA: Bool {
        switch self {
        case .general: return false
        case .nisa_tsumitate, .nisa_growth: return true
        }
    }

    /// 该账户类型允许的市场
    var allowedMarkets: [Market] {
        switch self {
        case .general:
            return Market.allCases
        case .nisa_tsumitate:
            return [.JP_FUND]
        case .nisa_growth:
            return [.JP, .JP_FUND]
        }
    }

    /// 是否需要验证つみたて対象商品
    var requiresTsumitateEligible: Bool {
        self == .nisa_tsumitate
    }

    var annualLimitInManYen: Double? {
        switch self {
        case .general: return nil
        case .nisa_tsumitate:   return 120
        case .nisa_growth:      return 240
        }
    }

    var annualLimit: Double? {
        guard let manYen = annualLimitInManYen else { return nil }
        return manYen * 10000
    }

    static let lifetimeLimitInManYen: Double = 1800
    static let lifetimeLimit: Double = 1800 * 10000

    static let growthLifetimeLimitInManYen: Double = 1200
    static let growthLifetimeLimit: Double = 1200 * 10000

    var color: Color {
        switch self {
        case .general: return .blue
        case .nisa_tsumitate:   return Color(red: 0.298, green: 0.686, blue: 0.314)
        case .nisa_growth:      return Color(red: 0.129, green: 0.588, blue: 0.953)
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

// MARK: - Time Range (Apple Stocks Style)

enum TimeRange: String, CaseIterable, Identifiable {
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "1Y"
    case twoYears = "2Y"
    case fiveYears = "5Y"
    case all = "ALL"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var days: Int? {
        switch self {
        case .day:         return 1
        case .week:        return 7
        case .month:       return 30
        case .threeMonths: return 90
        case .sixMonths:   return 180
        case .year:        return 365
        case .twoYears:    return 730
        case .fiveYears:   return 1825
        case .all:         return nil
        }
    }

    var yahooInterval: String {
        switch self {
        case .day:         return "5m"
        case .week:        return "15m"
        case .month:       return "1h"
        case .threeMonths: return "1d"
        case .sixMonths:   return "1d"
        case .year:        return "1d"
        case .twoYears:    return "1wk"
        case .fiveYears:   return "1wk"
        case .all:         return "1mo"
        }
    }

    var yahooRange: String {
        switch self {
        case .day:         return "1d"
        case .week:        return "5d"
        case .month:       return "1mo"
        case .threeMonths: return "3mo"
        case .sixMonths:   return "6mo"
        case .year:        return "1y"
        case .twoYears:    return "2y"
        case .fiveYears:   return "5y"
        case .all:         return "max"
        }
    }
}
