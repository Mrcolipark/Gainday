import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ShareCardView: View {
    let month: Date
    let snapshots: [DailySnapshot]
    let baseCurrency: String
    let format: ShareImageService.ShareFormat

    private var weekdayLabels: [String] {
        ["周日".localized, "一".localized, "二".localized, "三".localized, "四".localized, "五".localized, "六".localized]
    }

    // 使用固定颜色确保渲染一致性
    private let bgGradientStart = Color(red: 0.08, green: 0.08, blue: 0.12)
    private let bgGradientEnd = Color(red: 0.04, green: 0.04, blue: 0.06)
    private let textWhite = Color.white
    private let profitColor = Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
    private let lossColor = Color(red: 1.0, green: 0.231, blue: 0.188) // #FF3B30
    private let cardBg = Color(white: 0.15)

    private var monthSnapMap: [Date: DailySnapshot] {
        var map: [Date: DailySnapshot] = [:]
        for snap in snapshots {
            map[snap.date.startOfDay] = snap
        }
        return map
    }

    private var totalPnL: Double {
        snapshots.reduce(0) { $0 + $1.dailyPnL }
    }

    private var totalPnLPercent: Double {
        let totalCost = snapshots.last?.totalCost ?? 0
        guard totalCost > 0 else { return 0 }
        return totalPnL / totalCost * 100
    }

    private var profitDays: Int {
        snapshots.filter { $0.dailyPnL > 0 }.count
    }

    private var lossDays: Int {
        snapshots.filter { $0.dailyPnL < 0 }.count
    }

    private var winRate: Double {
        let total = profitDays + lossDays
        guard total > 0 else { return 0 }
        return Double(profitDays) / Double(total) * 100
    }

    init(
        month: Date,
        snapshots: [DailySnapshot],
        baseCurrency: String,
        format: ShareImageService.ShareFormat = .square
    ) {
        self.month = month
        self.snapshots = snapshots
        self.baseCurrency = baseCurrency
        self.format = format
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [bgGradientStart, bgGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                // Summary Stats
                summarySection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                // Calendar Grid with details
                calendarSection
                    .padding(.horizontal, 12)

                Spacer(minLength: 12)

                // Footer
                footerSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .frame(width: format.size.width, height: format.size.height)
        .clipped()
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text(month.monthYearString)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(textWhite)

            Text("投资月报".localized)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(textWhite.opacity(0.6))
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        HStack(spacing: 12) {
            // 本月盈亏
            VStack(alignment: .leading, spacing: 4) {
                Text("本月盈亏".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textWhite.opacity(0.5))

                Text(formatCurrency(totalPnL, showSign: true))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(totalPnL >= 0 ? profitColor : lossColor)

                Text(formatPercent(totalPnLPercent, showSign: true))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(totalPnL >= 0 ? profitColor.opacity(0.8) : lossColor.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBg)
            )

            // 胜率统计
            VStack(alignment: .leading, spacing: 4) {
                Text("交易统计".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textWhite.opacity(0.5))

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Circle().fill(profitColor).frame(width: 8, height: 8)
                        Text("\(profitDays)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(profitColor)
                    }
                    Text("/")
                        .foregroundColor(textWhite.opacity(0.3))
                    HStack(spacing: 3) {
                        Circle().fill(lossColor).frame(width: 8, height: 8)
                        Text("\(lossDays)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(lossColor)
                    }
                }

                Text("\("胜率".localized) \(String(format: "%.0f%%", winRate))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(textWhite.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBg)
            )
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(spacing: 4) {
            // Weekday headers
            HStack(spacing: 4) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(textWhite.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, dateOpt in
                    if let date = dateOpt {
                        dayCell(for: date)
                    } else {
                        // 空白占位，高度与有数据的格子一致
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBg.opacity(0.5))
        )
    }

    private func dayCell(for date: Date) -> some View {
        let snap = monthSnapMap[date.startOfDay]
        let pnl = snap?.dailyPnL ?? 0
        let pct = snap?.dailyPnLPercent ?? 0
        let hasData = snap != nil

        return VStack(spacing: 2) {
            // 日期
            Text("\(date.day)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(textWhite.opacity(hasData ? 0.95 : 0.3))

            if hasData {
                // 金额
                Text(formatCompactPnL(pnl))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(pnl >= 0 ? profitColor : lossColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // 百分比
                Text(formatCompactPercent(pct))
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(pnl >= 0 ? profitColor.opacity(0.8) : lossColor.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                // 占位 - 保持高度一致
                Text("-")
                    .font(.system(size: 9))
                    .foregroundColor(textWhite.opacity(0.15))
                Text("-")
                    .font(.system(size: 8))
                    .foregroundColor(.clear)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hasData ? pnlColor(percent: pct).opacity(0.3) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    hasData ? pnlColor(percent: pct).opacity(0.5) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: 12) {
            #if os(iOS)
            if let qrImage = ShareImageService.generateQRCode(from: "https://apps.apple.com") {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            #endif

            VStack(alignment: .leading, spacing: 2) {
                Text("GainDay")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(textWhite)
                Text("盈历 - 投资日历".localized)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textWhite.opacity(0.5))
            }

            Spacer()
        }
    }

    // MARK: - Calendar Days

    private var calendarDays: [Date?] {
        month.calendarDays()
    }

    // MARK: - PnL Color

    private func pnlColor(percent: Double) -> Color {
        switch percent {
        case ..<(-5):   return Color(red: 0.718, green: 0.110, blue: 0.110)
        case ..<(-3):   return Color(red: 0.776, green: 0.157, blue: 0.157)
        case ..<(-2):   return Color(red: 0.827, green: 0.184, blue: 0.184)
        case ..<(-1):   return Color(red: 0.898, green: 0.224, blue: 0.208)
        case ..<(-0.5): return Color(red: 0.937, green: 0.325, blue: 0.314)
        case ..<0:      return Color(red: 0.957, green: 0.263, blue: 0.212)
        case 0:         return Color(white: 0.38)
        case ..<0.5:    return Color(red: 0.298, green: 0.686, blue: 0.314)
        case ..<1:      return Color(red: 0.263, green: 0.627, blue: 0.278)
        case ..<2:      return Color(red: 0.220, green: 0.557, blue: 0.235)
        case ..<3:      return Color(red: 0.180, green: 0.490, blue: 0.196)
        case ..<5:      return Color(red: 0.106, green: 0.369, blue: 0.125)
        default:        return Color(red: 0.051, green: 0.325, blue: 0.008)
        }
    }

    // MARK: - Formatting Helpers

    private func formatCurrency(_ value: Double, showSign: Bool = false) -> String {
        let absValue = abs(value)
        var result: String

        if absValue >= 100_000_000 {
            result = String(format: "%.1f亿", absValue / 100_000_000)
        } else if absValue >= 10_000 {
            result = String(format: "%.1f万", absValue / 10_000)
        } else {
            result = String(format: "%.0f", absValue)
        }

        if showSign {
            if value > 0 {
                result = "+" + result
            } else if value < 0 {
                result = "-" + result
            }
        } else if value < 0 {
            result = "-" + result
        }

        let symbol: String
        switch baseCurrency {
        case "JPY": symbol = "¥"
        case "USD": symbol = "$"
        case "CNY": symbol = "¥"
        case "HKD": symbol = "HK$"
        default: symbol = ""
        }

        return symbol + result
    }

    private func formatCompactPnL(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value >= 0 ? "+" : "-"

        if absValue >= 100_000_000 {
            return sign + String(format: "%.0f亿", absValue / 100_000_000)
        } else if absValue >= 10_000_000 {
            return sign + String(format: "%.0f万", absValue / 10_000)
        } else if absValue >= 10_000 {
            return sign + String(format: "%.1f万", absValue / 10_000)
        } else if absValue >= 1000 {
            return sign + String(format: "%.1fk", absValue / 1000)
        } else {
            return sign + String(format: "%.0f", absValue)
        }
    }

    private func formatPercent(_ value: Double, showSign: Bool = false) -> String {
        let sign = showSign ? (value >= 0 ? "+" : "") : ""
        return sign + String(format: "%.2f%%", value)
    }

    private func formatCompactPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return sign + String(format: "%.1f%%", value)
    }
}

#Preview {
    ShareCardView(
        month: Date(),
        snapshots: [],
        baseCurrency: "JPY",
        format: .square
    )
}
