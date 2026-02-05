import SwiftUI

enum AppFonts {
    // Monetary amounts - keep .rounded
    static let largeAmount = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let mediumAmount = Font.system(.title, design: .rounded, weight: .bold)
    static let smallAmount = Font.system(.title3, design: .rounded, weight: .semibold)

    // Body/headline/card fonts - SF Pro (default) for Yahoo-like text
    static let headline = Font.system(.headline, design: .default, weight: .semibold)
    static let subheadline = Font.system(.subheadline, design: .default, weight: .regular)

    static let calendarDay = Font.system(.caption2, design: .default, weight: .medium)
    static let calendarPnL = Font.system(size: 8, weight: .semibold, design: .default)

    static let cardTitle = Font.system(.headline, design: .default, weight: .semibold)
    static let cardSubtitle = Font.system(.subheadline, design: .default)
    static let cardBody = Font.system(.body, design: .default)

    // Yahoo Finance-style ticker fonts
    static let tickerSymbol = Font.system(.subheadline, design: .default, weight: .bold)
    static let tickerName = Font.system(.caption, design: .default, weight: .regular)
    static let marketPrice = Font.system(.title3, design: .monospaced, weight: .semibold)
    static let changeAmount = Font.system(.caption, design: .monospaced, weight: .medium)

    // Widget fonts
    static let widgetLargeNumber = Font.system(.title, design: .rounded, weight: .bold)
    static let widgetSmallNumber = Font.system(.caption, design: .rounded, weight: .medium)
}
