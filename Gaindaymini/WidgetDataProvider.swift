import Foundation
import WidgetKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Shared Constants

enum WidgetConstants {
    /// App Group identifier for sharing data between main app and widgets
    /// NOTE: You need to add this App Group capability in Xcode:
    /// 1. Select both Gainday and Gaindaymini targets
    /// 2. Go to Signing & Capabilities
    /// 3. Add "App Groups" capability
    /// 4. Add this group identifier
    static let appGroupIdentifier = "group.com.gainday.shared"
}

// MARK: - Widget Language Manager

struct WidgetLanguageManager {
    static var shared = WidgetLanguageManager()

    /// Shared UserDefaults for App Group
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetConstants.appGroupIdentifier)
    }

    /// 当前实际使用的语言代码
    var effectiveLanguage: String {
        // Try shared defaults first, fallback to standard
        let language = sharedDefaults?.string(forKey: "appLanguage")
            ?? UserDefaults.standard.string(forKey: "appLanguage")
            ?? "system"
        if language == "system" {
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh-CN") {
                return "zh-Hans"
            } else if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") || preferred.hasPrefix("zh-HK") {
                return "zh-Hant"
            } else if preferred.hasPrefix("ja") {
                return "ja"
            } else {
                return "en"
            }
        }
        return language
    }

    /// 获取本地化字符串
    func localized(_ key: String) -> String {
        return Self.strings[key]?[effectiveLanguage] ?? key
    }

    // MARK: - Widget Translation Dictionary

    private static let strings: [String: [String: String]] = [
        // DailyPnLWidget
        "今日盈亏": ["zh-Hans": "今日盈亏", "zh-Hant": "今日盈虧", "en": "Today's P&L", "ja": "本日損益"],
        "总资产": ["zh-Hans": "总资产", "zh-Hant": "總資產", "en": "Total Assets", "ja": "総資産"],

        // WatchlistWidget
        "持仓": ["zh-Hans": "持仓", "zh-Hant": "持倉", "en": "Holdings", "ja": "保有"],

        // MonthHeatmapWidget
        "年": ["zh-Hans": "年", "zh-Hant": "年", "en": " ", "ja": "年"],
        "月": ["zh-Hans": "月", "zh-Hant": "月", "en": "", "ja": "月"],
        "天": ["zh-Hans": "天", "zh-Hant": "天", "en": "d", "ja": "日"],
        "胜率": ["zh-Hans": "胜率", "zh-Hant": "勝率", "en": "Win", "ja": "勝率"],
        "亏": ["zh-Hans": "亏", "zh-Hant": "虧", "en": "L", "ja": "負"],
        "盈": ["zh-Hans": "盈", "zh-Hant": "盈", "en": "W", "ja": "勝"],

        // Weekday Labels
        "周日": ["zh-Hans": "日", "zh-Hant": "日", "en": "S", "ja": "日"],
        "周一": ["zh-Hans": "一", "zh-Hant": "一", "en": "M", "ja": "月"],
        "周二": ["zh-Hans": "二", "zh-Hant": "二", "en": "T", "ja": "火"],
        "周三": ["zh-Hans": "三", "zh-Hant": "三", "en": "W", "ja": "水"],
        "周四": ["zh-Hans": "四", "zh-Hant": "四", "en": "T", "ja": "木"],
        "周五": ["zh-Hans": "五", "zh-Hant": "五", "en": "F", "ja": "金"],
        "周六": ["zh-Hans": "六", "zh-Hant": "六", "en": "S", "ja": "土"],

        // Widget Display Names & Descriptions
        "今日盈亏Widget": ["zh-Hans": "今日盈亏", "zh-Hant": "今日盈虧", "en": "Today's P&L", "ja": "本日損益"],
        "显示今日盈亏和总资产": ["zh-Hans": "显示今日盈亏和总资产", "zh-Hant": "顯示今日盈虧和總資產", "en": "Shows today's P&L and total assets", "ja": "本日の損益と総資産を表示"],
        "持仓列表": ["zh-Hans": "持仓列表", "zh-Hant": "持倉列表", "en": "Holdings List", "ja": "保有一覧"],
        "实时查看持仓涨跌": ["zh-Hans": "实时查看持仓涨跌", "zh-Hant": "即時查看持倉漲跌", "en": "View holdings changes in real-time", "ja": "保有の変動をリアルタイムで確認"],
        "月度热力图": ["zh-Hans": "月度热力图", "zh-Hant": "月度熱力圖", "en": "Monthly Heatmap", "ja": "月間ヒートマップ"],
        "当月每日盈亏日历": ["zh-Hans": "当月每日盈亏日历", "zh-Hant": "當月每日盈虧日曆", "en": "Daily P&L calendar for current month", "ja": "当月の日次損益カレンダー"],
    ]
}

// MARK: - String Extension for Widget Localization

extension String {
    var widgetLocalized: String {
        WidgetLanguageManager.shared.localized(self)
    }
}

// MARK: - Double Extension for Widget

extension Double {
    func compactFormatted(code: String = "JPY", showSign: Bool = false) -> String {
        let absValue = abs(self)
        let sign: String
        if self < 0 {
            sign = "-"
        } else if showSign && self > 0 {
            sign = "+"
        } else {
            sign = ""
        }
        let currencySymbol: String
        switch code {
        case "JPY": currencySymbol = "¥"
        case "CNY": currencySymbol = "¥"
        case "USD": currencySymbol = "$"
        case "HKD": currencySymbol = "HK$"
        default: currencySymbol = code
        }

        let lang = WidgetLanguageManager.shared.effectiveLanguage
        let useWan = (lang == "zh-Hans" || lang == "zh-Hant" || lang == "ja")

        if useWan {
            if absValue >= 100_000_000 {
                return "\(sign)\(currencySymbol)\(String(format: "%.1f", absValue / 100_000_000))亿"
            } else if absValue >= 10_000 {
                return "\(sign)\(currencySymbol)\(String(format: "%.1f", absValue / 10_000))万"
            } else {
                return "\(sign)\(currencySymbol)\(String(format: "%.0f", absValue))"
            }
        } else {
            if absValue >= 1_000_000 {
                return "\(sign)\(currencySymbol)\(String(format: "%.1f", absValue / 1_000_000))M"
            } else if absValue >= 1_000 {
                return "\(sign)\(currencySymbol)\(String(format: "%.1f", absValue / 1_000))K"
            } else {
                return "\(sign)\(currencySymbol)\(String(format: "%.0f", absValue))"
            }
        }
    }
}

// MARK: - Date Extension for Widget

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}

// MARK: - Widget Color Helpers

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

enum WidgetColors {
    // iOS System Colors - Apple/Yahoo Finance Style
    static let profit = Color(hex: 0x34C759)  // iOS 系统绿
    static let loss = Color(hex: 0xFF3B30)    // iOS 系统红

    /// 自适应空单元格颜色
    static var emptyCell: Color {
        WidgetTheme.color(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.08))
    }

    /// 自适应今日边框颜色
    static var todayBorder: Color {
        WidgetTheme.color(light: Color.black.opacity(0.8), dark: Color.white)
    }

    /// 热力图文字阴影
    static var cellTextShadow: Color {
        WidgetTheme.color(light: Color.white.opacity(0.4), dark: Color.black.opacity(0.3))
    }
}

// MARK: - Widget Theme

enum WidgetTheme {
    /// 判断当前是否深色模式（优先读 App 偏好，否则跟随系统）
    static var isDark: Bool {
        if let defaults = UserDefaults(suiteName: WidgetConstants.appGroupIdentifier),
           let appearance = defaults.string(forKey: "appearance") {
            switch appearance {
            case "light": return false
            case "dark": return true
            default: break  // "system" — 跟随系统
            }
        }
        // 跟随系统
        #if canImport(UIKit)
        return UIScreen.main.traitCollection.userInterfaceStyle == .dark
        #else
        return true
        #endif
    }

    /// 根据主题选择颜色
    static func color(light: Color, dark: Color) -> Color {
        isDark ? dark : light
    }

    /// Widget 背景色
    static var widgetBackground: Color {
        isDark ? Color(hex: 0x1C1C1E) : Color(hex: 0xF2F2F7)
    }

    /// 主要文字色
    static var textPrimary: Color {
        isDark ? .white : .black
    }

    /// 次要文字色
    static var textSecondary: Color {
        isDark ? Color(hex: 0x8E8E93) : Color(hex: 0x6C6C70)
    }

    /// 第三级文字色
    static var textTertiary: Color {
        isDark ? Color(hex: 0x636366) : Color(hex: 0x8E8E93)
    }
}

extension View {
    /// 应用主 App 的主题偏好到 Widget
    func widgetTheme() -> some View {
        self.environment(\.colorScheme, WidgetTheme.isDark ? .dark : .light)
    }
}

// MARK: - Data Models

struct WidgetPnLData {
    let totalValue: Double
    let dailyPnL: Double
    let dailyPnLPercent: Double
    let baseCurrency: String
    let date: Date
    let isEmpty: Bool

    init(totalValue: Double, dailyPnL: Double, dailyPnLPercent: Double, baseCurrency: String, date: Date, isEmpty: Bool = false) {
        self.totalValue = totalValue
        self.dailyPnL = dailyPnL
        self.dailyPnLPercent = dailyPnLPercent
        self.baseCurrency = baseCurrency
        self.date = date
        self.isEmpty = isEmpty
    }

    static let placeholder = WidgetPnLData(
        totalValue: 1_234_567,
        dailyPnL: 12_340,
        dailyPnLPercent: 1.23,
        baseCurrency: "JPY",
        date: Date()
    )

    static let empty = WidgetPnLData(
        totalValue: 0,
        dailyPnL: 0,
        dailyPnLPercent: 0,
        baseCurrency: "JPY",
        date: Date(),
        isEmpty: true
    )
}

// MARK: - Data Loading

struct WidgetDataLoader {
    static func loadLatestPnL() -> WidgetPnLData {
        // 优先从 App Group UserDefaults 读取（可靠）
        if let defaults = UserDefaults(suiteName: WidgetConstants.appGroupIdentifier) {
            let totalValue = defaults.double(forKey: "widget_totalValue")
            let dailyPnL = defaults.double(forKey: "widget_dailyPnL")
            let dailyPnLPercent = defaults.double(forKey: "widget_dailyPnLPercent")
            let baseCurrency = defaults.string(forKey: "widget_baseCurrency") ?? "JPY"
            let lastUpdate = defaults.double(forKey: "widget_lastUpdate")

            // 只要有过数据写入就使用
            if lastUpdate > 0 {
                let date = Date(timeIntervalSince1970: lastUpdate)
                return WidgetPnLData(
                    totalValue: totalValue,
                    dailyPnL: dailyPnL,
                    dailyPnLPercent: dailyPnLPercent,
                    baseCurrency: baseCurrency,
                    date: date
                )
            }
        }

        return .empty
    }
}
