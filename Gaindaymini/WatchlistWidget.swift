import WidgetKit
import SwiftUI
import Charts

// MARK: - Timeline Provider

struct WatchlistProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchlistEntry {
        WatchlistEntry(date: Date(), stocks: WatchlistStock.placeholders)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchlistEntry) -> Void) {
        Task {
            let stocks = await WidgetStockService.shared.fetchWatchlistStocks()
            completion(WatchlistEntry(date: Date(), stocks: stocks))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchlistEntry>) -> Void) {
        Task {
            let stocks = await WidgetStockService.shared.fetchWatchlistStocks()
            let entry = WatchlistEntry(date: Date(), stocks: stocks)

            // 智能刷新策略
            let nextUpdate = calculateNextUpdate()
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    /// 计算下次更新时间 - 开盘时更频繁
    private func calculateNextUpdate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)

        // 周末：6小时后更新
        if weekday == 1 || weekday == 7 {
            return calendar.date(byAdding: .hour, value: 6, to: now)!
        }

        // 交易时段 (大致覆盖全球主要市场 8:00-22:00)
        if hour >= 8 && hour < 22 {
            return calendar.date(byAdding: .minute, value: 15, to: now)!
        }

        // 非交易时段：1小时后更新
        return calendar.date(byAdding: .hour, value: 1, to: now)!
    }
}

// MARK: - Entry

struct WatchlistEntry: TimelineEntry {
    let date: Date
    let stocks: [WatchlistStock]
}

// MARK: - Stock Model

struct WatchlistStock: Identifiable {
    let id: String
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let changePercent: Double
    let currency: String
    let sparklineData: [Double]

    var isProfit: Bool { changePercent >= 0 }

    var displaySymbol: String {
        symbol
            .replacingOccurrences(of: ".T", with: "")
            .replacingOccurrences(of: ".SS", with: "")
            .replacingOccurrences(of: ".SZ", with: "")
            .replacingOccurrences(of: ".HK", with: "")
    }

    var priceString: String {
        let sym: String
        switch currency {
        case "JPY", "CNY": sym = "¥"
        case "USD": sym = "$"
        case "HKD": sym = "HK$"
        default: sym = ""
        }

        if currency == "JPY" {
            return "\(sym)\(Int(price).formatted())"
        } else {
            return "\(sym)\(String(format: "%.2f", price))"
        }
    }

    /// 涨跌幅字符串 - 智能格式化避免截断
    var changeString: String {
        let absPercent = abs(changePercent)
        if absPercent >= 10 {
            return String(format: "%+.1f%%", changePercent)
        } else {
            return String(format: "%+.2f%%", changePercent)
        }
    }

    static let placeholders: [WatchlistStock] = [
        WatchlistStock(id: "AAPL", symbol: "AAPL", name: "Apple Inc.", price: 182.63, change: 2.25, changePercent: 1.25, currency: "USD", sparklineData: [180, 181, 180.5, 182, 181.5, 182.63]),
        WatchlistStock(id: "7203.T", symbol: "7203.T", name: "トヨタ自動車", price: 2845, change: -9.12, changePercent: -0.32, currency: "JPY", sparklineData: [2860, 2855, 2850, 2848, 2845, 2845]),
        WatchlistStock(id: "MSFT", symbol: "MSFT", name: "Microsoft", price: 420.00, change: 3.55, changePercent: 0.85, currency: "USD", sparklineData: [416, 417, 418, 419, 418.5, 420]),
        WatchlistStock(id: "9984.T", symbol: "9984.T", name: "ソフトバンクG", price: 8120, change: 167, changePercent: 2.10, currency: "JPY", sparklineData: [7950, 8000, 8050, 8080, 8100, 8120]),
        WatchlistStock(id: "NVDA", symbol: "NVDA", name: "NVIDIA", price: 875.50, change: 27.12, changePercent: 3.20, currency: "USD", sparklineData: [848, 855, 860, 865, 870, 875.5]),
        WatchlistStock(id: "0700.HK", symbol: "0700.HK", name: "腾讯控股", price: 298, change: -3.45, changePercent: -1.15, currency: "HKD", sparklineData: [302, 301, 300, 299, 298.5, 298]),
    ]
}

// MARK: - Large View

struct WatchlistLargeView: View {
    let stocks: [WatchlistStock]
    let updateTime: Date

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: updateTime)
    }

    var body: some View {
        GeometryReader { geo in
            let headerHeight: CGFloat = 20
            let stockCount = min(stocks.count, 6)
            let rowHeight = stockCount > 0 ? (geo.size.height - headerHeight) / CGFloat(stockCount) : 50

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("持仓".widgetLocalized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(timeString)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: headerHeight)

                // Stock list - 每行均分高度
                ForEach(stocks.prefix(6)) { stock in
                    LargeStockRow(stock: stock)
                        .frame(height: rowHeight)
                }
            }
        }
        .padding(12)
        .containerBackground(for: .widget) { WidgetTheme.widgetBackground }
    }
}

struct LargeStockRow: View {
    let stock: WatchlistStock

    var body: some View {
        HStack(spacing: 8) {
            // 左侧：代码 + 名称（垂直排列）
            VStack(alignment: .leading, spacing: 1) {
                Text(stock.displaySymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(stock.name)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(width: 70, alignment: .leading)

            // 中间：走势图（弹性宽度）
            WidgetSparkline(data: stock.sparklineData, isProfit: stock.isProfit)
                .frame(height: 24)

            // 右侧：价格 + 涨跌徽章
            VStack(alignment: .trailing, spacing: 2) {
                Text(stock.priceString)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(stock.changeString)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(stock.isProfit ? WidgetColors.profit : WidgetColors.loss)
            }
            .frame(width: 72, alignment: .trailing)
        }
    }
}

// MARK: - Widget Sparkline

struct WidgetSparkline: View {
    let data: [Double]
    let isProfit: Bool

    var body: some View {
        if data.count >= 2, let minVal = data.min(), let maxVal = data.max(), maxVal > minVal {
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("X", index),
                        y: .value("Y", value)
                    )
                    .foregroundStyle(isProfit ? WidgetColors.profit : WidgetColors.loss)
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartYScale(domain: minVal...maxVal)
        } else {
            // 无数据时显示水平线
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

// MARK: - Medium View

struct WatchlistMediumView: View {
    let stocks: [WatchlistStock]
    let updateTime: Date

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: updateTime)
    }

    var body: some View {
        GeometryReader { geo in
            let stockCount = min(stocks.count, 3)
            let headerHeight: CGFloat = 20
            let rowHeight = stockCount > 0 ? (geo.size.height - headerHeight) / CGFloat(stockCount) : 50

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("持仓".widgetLocalized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(timeString)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: headerHeight)

                ForEach(stocks.prefix(3)) { stock in
                    LargeStockRow(stock: stock)
                        .frame(height: rowHeight)
                }
            }
        }
        .padding(12)
        .containerBackground(for: .widget) { WidgetTheme.widgetBackground }
    }
}

// MARK: - Empty State View

struct WatchlistEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)

            Text("持仓".widgetLocalized)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { WidgetTheme.widgetBackground }
    }
}

// MARK: - Widget Entry View

struct WatchlistWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WatchlistEntry

    var body: some View {
        if entry.stocks.isEmpty {
            WatchlistEmptyView()
        } else {
            switch family {
            case .systemMedium:
                WatchlistMediumView(stocks: entry.stocks, updateTime: entry.date)
            default:
                WatchlistLargeView(stocks: entry.stocks, updateTime: entry.date)
            }
        }
    }
}

// MARK: - Widget

struct WatchlistWidget: Widget {
    let kind = "WatchlistWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchlistProvider()) { entry in
            WatchlistWidgetEntryView(entry: entry)
                .widgetTheme()
        }
        .configurationDisplayName("持仓列表".widgetLocalized)
        .description("实时查看持仓涨跌".widgetLocalized)
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("持仓 - 浅色") {
    WatchlistWidgetEntryView(entry: WatchlistEntry(date: Date(), stocks: WatchlistStock.placeholders))
        .containerBackground(for: .widget) { WidgetTheme.widgetBackground }
        .previewContext(WidgetPreviewContext(family: .systemLarge))
        .environment(\.colorScheme, .light)
}

#Preview("持仓 - 深色") {
    WatchlistWidgetEntryView(entry: WatchlistEntry(date: Date(), stocks: WatchlistStock.placeholders))
        .containerBackground(for: .widget) { WidgetTheme.widgetBackground }
        .previewContext(WidgetPreviewContext(family: .systemLarge))
        .environment(\.colorScheme, .dark)
}
