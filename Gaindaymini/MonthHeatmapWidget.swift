import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Provider

struct MonthHeatmapProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthHeatmapEntry {
        MonthHeatmapEntry(date: Date(), days: DayPnLData.placeholders, monthTotal: 125000, year: 2026, month: 2)
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthHeatmapEntry) -> Void) {
        let data = loadCurrentMonthPnL()
        completion(data)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthHeatmapEntry>) -> Void) {
        let entry = loadCurrentMonthPnL()

        // 每小时更新一次
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: - Load Data

    private func loadCurrentMonthPnL() -> MonthHeatmapEntry {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        do {
            let schema = Schema([DailySnapshot.self, Portfolio.self, Holding.self, Transaction.self, PriceCache.self])
            let config = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(WidgetConstants.appGroupIdentifier),
                cloudKitDatabase: .automatic
            )
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<DailySnapshot>()
            let snapshots = try context.fetch(descriptor)

            // 只取全局快照（portfolioID == nil）且当月的
            let monthSnapshots = snapshots.filter {
                $0.portfolioID == nil &&
                calendar.component(.year, from: $0.date) == year &&
                calendar.component(.month, from: $0.date) == month
            }

            // 按日期映射
            var dailyData: [Int: (pnL: Double, pnLPercent: Double)] = [:]
            for snapshot in monthSnapshots {
                let day = calendar.component(.day, from: snapshot.date)
                dailyData[day] = (pnL: snapshot.dailyPnL, pnLPercent: snapshot.dailyPnLPercent)
            }

            // 获取当月天数
            let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 31

            // 生成每天的数据
            let days = (1...daysInMonth).map { day in
                DayPnLData(
                    day: day,
                    pnL: dailyData[day]?.pnL ?? 0,
                    pnLPercent: dailyData[day]?.pnLPercent ?? 0,
                    hasData: dailyData[day] != nil
                )
            }

            let monthTotal = days.filter { $0.hasData }.reduce(0) { $0 + $1.pnL }

            return MonthHeatmapEntry(date: now, days: days, monthTotal: monthTotal, year: year, month: month)
        } catch {
            return MonthHeatmapEntry(date: now, days: DayPnLData.placeholders, monthTotal: 0, year: year, month: month)
        }
    }
}

// MARK: - Entry

struct MonthHeatmapEntry: TimelineEntry {
    let date: Date
    let days: [DayPnLData]
    let monthTotal: Double
    let year: Int
    let month: Int

    var monthString: String {
        let lang = WidgetLanguageManager.shared.effectiveLanguage
        switch lang {
        case "en":
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            let date = Calendar.current.date(from: DateComponents(year: year, month: month)) ?? Date()
            return formatter.string(from: date)
        default:
            return "\(year)\("年".widgetLocalized)\(month)\("月".widgetLocalized)"
        }
    }

    var profitDays: Int {
        days.filter { $0.hasData && $0.pnL > 0 }.count
    }

    var lossDays: Int {
        days.filter { $0.hasData && $0.pnL < 0 }.count
    }

    var winRate: Double {
        let total = profitDays + lossDays
        return total > 0 ? Double(profitDays) / Double(total) * 100 : 0
    }
}

// MARK: - Day Data Model

struct DayPnLData: Identifiable {
    let id: Int
    let day: Int
    let pnL: Double
    let pnLPercent: Double
    let hasData: Bool

    init(day: Int, pnL: Double, pnLPercent: Double = 0, hasData: Bool) {
        self.id = day
        self.day = day
        self.pnL = pnL
        self.pnLPercent = pnLPercent
        self.hasData = hasData
    }

    var isProfit: Bool { pnL >= 0 }

    /// 紧凑的盈亏字符串（多语言支持）
    var pnLCompact: String {
        let absValue = abs(pnL)
        let sign = pnL >= 0 ? "+" : "-"
        let lang = WidgetLanguageManager.shared.effectiveLanguage

        // 中日文用"万"，英文用"K"
        let useWan = (lang == "zh-Hans" || lang == "zh-Hant" || lang == "ja")

        if useWan {
            // 中日文：万为单位
            if absValue >= 10000 {
                return "\(sign)\(String(format: "%.0f", absValue / 10000))万"
            } else if absValue >= 1000 {
                return "\(sign)\(String(format: "%.1f", absValue / 1000))k"
            } else {
                return "\(sign)\(String(format: "%.0f", absValue))"
            }
        } else {
            // 英文：K为单位
            if absValue >= 1000000 {
                return "\(sign)\(String(format: "%.1f", absValue / 1000000))M"
            } else if absValue >= 1000 {
                return "\(sign)\(String(format: "%.0f", absValue / 1000))K"
            } else {
                return "\(sign)\(String(format: "%.0f", absValue))"
            }
        }
    }

    /// 热力图颜色
    var heatmapColor: Color {
        guard hasData else {
            return Color.white.opacity(0.08)
        }

        // 根据盈亏计算颜色强度（假设 ±2% 为满强度）
        let intensity = min(abs(pnL) / 20000, 1.0)
        let baseOpacity = 0.4
        let maxOpacity = 1.0

        if pnL >= 0 {
            return WidgetColors.profit.opacity(baseOpacity + intensity * (maxOpacity - baseOpacity))
        } else {
            return WidgetColors.loss.opacity(baseOpacity + intensity * (maxOpacity - baseOpacity))
        }
    }

    static let placeholders: [DayPnLData] = {
        let calendar = Calendar.current
        let year = 2026
        let month = 2
        return (1...28).map { day in
            let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7 // 周日=1, 周六=7
            let hasData = !isWeekend
            let pnLPercent = hasData ? Double.random(in: -5...5) : 0
            let pnL = hasData ? pnLPercent * 10000 : 0
            return DayPnLData(day: day, pnL: pnL, pnLPercent: pnLPercent, hasData: hasData)
        }
    }()
}

// MARK: - Widget View

struct MonthHeatmapWidgetView: View {
    let entry: MonthHeatmapEntry

    private var weekdayLabels: [String] {
        ["周日", "周一", "周二", "周三", "周四", "周五", "周六"].map { $0.widgetLocalized }
    }
    private let cellSpacing: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let calendar = Calendar.current
            let firstDayOfMonth = calendar.date(from: DateComponents(year: entry.year, month: entry.month, day: 1))!
            let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1
            let weeksCount = (firstWeekday + entry.days.count + 6) / 7

            let headerHeight: CGFloat = 44
            let weekdayHeight: CGFloat = 16
            let legendHeight: CGFloat = 24
            let gridHeight = geo.size.height - headerHeight - weekdayHeight - legendHeight - 12
            let cellSize = min(
                (geo.size.width - cellSpacing * 6) / 7,
                (gridHeight - cellSpacing * CGFloat(weeksCount - 1)) / CGFloat(weeksCount)
            )

            VStack(spacing: 6) {
                // Header
                headerView
                    .frame(height: headerHeight)

                // 星期标签
                HStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(weekdayLabels[i])
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: cellSize)
                    }
                }
                .frame(height: weekdayHeight)

                // 日历热力图
                VStack(spacing: cellSpacing) {
                    ForEach(0..<weeksCount, id: \.self) { week in
                        HStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { weekday in
                                let dayIndex = week * 7 + weekday - firstWeekday
                                if dayIndex >= 0 && dayIndex < entry.days.count {
                                    dayCell(data: entry.days[dayIndex], size: cellSize)
                                } else {
                                    Color.clear.frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                // 颜色图例
                colorLegend
                    .frame(height: legendHeight)
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 4) {
            HStack {
                Text(entry.monthString)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                // 月盈亏徽章
                Text(entry.monthTotal.widgetCompactFormatted(showSign: true))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(entry.monthTotal >= 0 ? WidgetColors.profit : WidgetColors.loss)
                    )
            }

            HStack {
                // 盈/亏天数 + 胜率
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(WidgetColors.profit).frame(width: 8, height: 8)
                        Text("\(entry.profitDays)\("天".widgetLocalized)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(WidgetColors.loss).frame(width: 8, height: 8)
                        Text("\(entry.lossDays)\("天".widgetLocalized)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("\("胜率".widgetLocalized) \(String(format: "%.0f%%", entry.winRate))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(entry.winRate >= 50 ? WidgetColors.profit : WidgetColors.loss)
                }
                Spacer()
            }
        }
    }

    // MARK: - Day Cell (纯色方块，参考分享功能)

    private func dayCell(data: DayPnLData, size: CGFloat) -> some View {
        let calendar = Calendar.current
        let today = Date()
        let isToday = calendar.component(.day, from: today) == data.day &&
                      calendar.component(.month, from: today) == entry.month &&
                      calendar.component(.year, from: today) == entry.year

        return ZStack {
            // 热力图颜色方块
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(data.hasData ? pnlColor(percent: data.pnLPercent) : Color.white.opacity(0.08))

            // 盈亏数字（有数据时显示）
            if data.hasData {
                Text(data.pnLCompact)
                    .font(.system(size: size > 36 ? 9 : 7, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            // 今日边框
            if isToday {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(.white, lineWidth: 2)
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Color Legend

    private var colorLegend: some View {
        HStack(spacing: 6) {
            Text("亏".widgetLocalized)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WidgetColors.loss)

            HStack(spacing: 2) {
                ForEach([-5.0, -2.0, -0.5, 0, 0.5, 2.0, 5.0], id: \.self) { pct in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(pnlColor(percent: pct))
                        .frame(width: 18, height: 12)
                }
            }

            Text("盈".widgetLocalized)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WidgetColors.profit)
        }
    }

    // MARK: - PnL Color (参考分享功能的颜色系统)

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
}

// MARK: - Double Extension

private extension Double {
    func widgetCompactFormatted(showSign: Bool = false) -> String {
        let absValue = abs(self)
        let sign: String
        if self < 0 {
            sign = "-"
        } else if showSign && self > 0 {
            sign = "+"
        } else {
            sign = ""
        }

        if absValue >= 100_000_000 {
            return "\(sign)¥\(String(format: "%.1f", absValue / 100_000_000))亿"
        } else if absValue >= 10_000 {
            return "\(sign)¥\(String(format: "%.1f", absValue / 10_000))万"
        } else {
            return "\(sign)¥\(String(format: "%.0f", absValue))"
        }
    }
}

// MARK: - Widget

struct MonthHeatmapWidget: Widget {
    let kind = "MonthHeatmapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonthHeatmapProvider()) { entry in
            MonthHeatmapWidgetView(entry: entry)
        }
        .configurationDisplayName("月度热力图".widgetLocalized)
        .description("当月每日盈亏日历".widgetLocalized)
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Previews

#Preview("热力图 - 浅色") {
    MonthHeatmapWidgetView(entry: MonthHeatmapEntry(date: Date(), days: DayPnLData.placeholders, monthTotal: 125000, year: 2026, month: 2))
        .containerBackground(.fill.tertiary, for: .widget)
        .previewContext(WidgetPreviewContext(family: .systemLarge))
        .environment(\.colorScheme, .light)
}

#Preview("热力图 - 深色") {
    MonthHeatmapWidgetView(entry: MonthHeatmapEntry(date: Date(), days: DayPnLData.placeholders, monthTotal: 125000, year: 2026, month: 2))
        .containerBackground(.fill.tertiary, for: .widget)
        .previewContext(WidgetPreviewContext(family: .systemLarge))
        .environment(\.colorScheme, .dark)
}
