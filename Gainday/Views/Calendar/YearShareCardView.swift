import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// 年度分享卡片 - 紧凑布局，分为上下半年两行
struct YearShareCardView: View {
    let year: Int
    let snapshots: [Date: DailySnapshot]
    let baseCurrency: String

    // 固定颜色
    private let bgGradientStart = Color(red: 0.08, green: 0.08, blue: 0.12)
    private let bgGradientEnd = Color(red: 0.04, green: 0.04, blue: 0.06)
    private let textWhite = Color.white
    private let profitColor = Color(red: 0.204, green: 0.780, blue: 0.349)
    private let lossColor = Color(red: 1.0, green: 0.231, blue: 0.188)
    private let cardBg = Color(white: 0.15)

    private let cellSize: CGFloat = 8
    private let cellSpacing: CGFloat = 2
    private let monthLabels = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]

    private var yearSnapshots: [DailySnapshot] {
        snapshots.values.filter { $0.date.year == year }
    }

    private var totalPnL: Double {
        yearSnapshots.reduce(0) { $0 + $1.dailyPnL }
    }

    private var profitDays: Int {
        yearSnapshots.filter { $0.dailyPnL > 0 }.count
    }

    private var lossDays: Int {
        yearSnapshots.filter { $0.dailyPnL < 0 }.count
    }

    private var winRate: Double {
        let total = profitDays + lossDays
        guard total > 0 else { return 0 }
        return Double(profitDays) / Double(total) * 100
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [bgGradientStart, bgGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 16) {
                // 标题
                headerSection

                // 汇总统计
                summarySection

                // 上半年热力图 (1-6月)
                halfYearHeatmap(months: 0..<6, title: "上半年")

                // 下半年热力图 (7-12月)
                halfYearHeatmap(months: 6..<12, title: "下半年")

                // 颜色图例
                colorLegend

                // 底部
                footerSection
            }
            .padding(20)
        }
        .frame(width: 480, height: 640)
        .clipped()
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("\(String(year))年度")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(textWhite)

            Text("投资年报")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textWhite.opacity(0.6))
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        HStack(spacing: 12) {
            // 年度盈亏
            VStack(alignment: .leading, spacing: 4) {
                Text("年度盈亏")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textWhite.opacity(0.5))

                Text(formatCurrency(totalPnL, showSign: true))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(totalPnL >= 0 ? profitColor : lossColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(cardBg))

            // 胜率
            VStack(alignment: .leading, spacing: 4) {
                Text("交易统计")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textWhite.opacity(0.5))

                HStack(spacing: 6) {
                    HStack(spacing: 2) {
                        Circle().fill(profitColor).frame(width: 6, height: 6)
                        Text("\(profitDays)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(profitColor)
                    }
                    Text("/")
                        .foregroundColor(textWhite.opacity(0.3))
                    HStack(spacing: 2) {
                        Circle().fill(lossColor).frame(width: 6, height: 6)
                        Text("\(lossDays)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(lossColor)
                    }
                    Text("胜率\(String(format: "%.0f%%", winRate))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textWhite.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(cardBg))
        }
    }

    // MARK: - Half Year Heatmap

    private func halfYearHeatmap(months: Range<Int>, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(textWhite.opacity(0.6))

            // 月份标签
            HStack(spacing: 0) {
                ForEach(months, id: \.self) { monthIndex in
                    Text(monthLabels[monthIndex])
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(textWhite.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // 热力图网格
            HStack(spacing: 4) {
                ForEach(months, id: \.self) { monthIndex in
                    monthHeatmap(month: monthIndex + 1)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(cardBg.opacity(0.5)))
    }

    private func monthHeatmap(month: Int) -> some View {
        let days = daysInMonth(month)
        let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: 7)

        return LazyVGrid(columns: columns, spacing: cellSpacing) {
            // 前导空白
            let firstDay = firstDayOfMonth(month)
            let offset = firstDay.weekday - 1
            ForEach(0..<offset, id: \.self) { _ in
                Color.clear.frame(width: cellSize, height: cellSize)
            }

            // 日期格子
            ForEach(days, id: \.self) { date in
                let snap = snapshots[date.startOfDay]
                let pct = snap?.dailyPnLPercent ?? 0
                let hasData = snap != nil

                RoundedRectangle(cornerRadius: 2)
                    .fill(hasData ? pnlColor(percent: pct) : Color.white.opacity(0.05))
                    .frame(width: cellSize, height: cellSize)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func daysInMonth(_ month: Int) -> [Date] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }

        return range.compactMap { day in
            calendar.date(from: DateComponents(year: year, month: month, day: day))
        }
    }

    private func firstDayOfMonth(_ month: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    // MARK: - Color Legend

    private var colorLegend: some View {
        HStack(spacing: 8) {
            Text("亏损")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(lossColor)

            HStack(spacing: 2) {
                ForEach([-5.0, -2.0, -0.5, 0, 0.5, 2.0, 5.0], id: \.self) { pct in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(pnlColor(percent: pct))
                        .frame(width: 16, height: 12)
                }
            }

            Text("盈利")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(profitColor)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 12) {
            #if os(iOS)
            if let qrImage = ShareImageService.generateQRCode(from: "https://apps.apple.com") {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            #endif

            VStack(alignment: .leading, spacing: 2) {
                Text("GainDay")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(textWhite)
                Text("盈历 - 投资日历")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(textWhite.opacity(0.5))
            }

            Spacer()
        }
    }

    // MARK: - Helpers

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
}

#Preview {
    YearShareCardView(year: 2026, snapshots: [:], baseCurrency: "JPY")
}
