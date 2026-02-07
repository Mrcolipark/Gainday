import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct HoldingsProvider: TimelineProvider {
    func placeholder(in context: Context) -> HoldingsEntry {
        HoldingsEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (HoldingsEntry) -> Void) {
        let data = WidgetDataLoader.loadTopHoldings()
        completion(HoldingsEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HoldingsEntry>) -> Void) {
        let data = WidgetDataLoader.loadTopHoldings()
        let entry = HoldingsEntry(date: Date(), data: data)
        // 15分钟刷新一次
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct HoldingsEntry: TimelineEntry {
    let date: Date
    let data: WidgetHoldingsData
}

// MARK: - Widget Views

struct HoldingsWidgetSmallView: View {
    let entry: HoldingsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            Text("持仓")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            // Holdings list (show top 3)
            let holdings = Array(entry.data.holdings.prefix(3))
            if holdings.isEmpty {
                Text("暂无持仓")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(holdings) { holding in
                    HStack {
                        Text(holding.symbol.replacingOccurrences(of: ".T", with: ""))
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .lineLimit(1)

                        Spacer()

                        Text(holding.changePercent.percentFormatted())
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(holding.changePercent >= 0 ? WidgetColors.profit : WidgetColors.loss)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct HoldingsWidgetMediumView: View {
    let entry: HoldingsEntry

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: entry.data.lastUpdate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("持仓")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                Spacer()
                Text("更新 \(timeString)")
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Holdings list (show top 4-5)
            let holdings = Array(entry.data.holdings.prefix(4))
            if holdings.isEmpty {
                VStack {
                    Spacer()
                    Text("暂无持仓")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ForEach(holdings) { holding in
                    HoldingRow(holding: holding)
                }
            }

            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct HoldingRow: View {
    let holding: WidgetHolding

    private var displaySymbol: String {
        // 简化显示：移除 .T 后缀等
        holding.symbol
            .replacingOccurrences(of: ".T", with: "")
            .replacingOccurrences(of: ".SS", with: "")
            .replacingOccurrences(of: ".SZ", with: "")
            .replacingOccurrences(of: ".HK", with: "")
    }

    private var priceString: String {
        let symbol: String
        switch holding.currency {
        case "JPY": symbol = "¥"
        case "USD": symbol = "$"
        case "HKD": symbol = "HK$"
        case "CNY": symbol = "¥"
        default: symbol = ""
        }

        if holding.currency == "JPY" {
            return "\(symbol)\(Int(holding.price).formatted())"
        } else {
            return "\(symbol)\(String(format: "%.2f", holding.price))"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Symbol
            Text(displaySymbol)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .frame(width: 50, alignment: .leading)
                .lineLimit(1)

            Spacer()

            // Price
            Text(priceString)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            // Change percent with indicator
            HStack(spacing: 2) {
                Text(holding.changePercent.percentFormatted())
                    .font(.system(.caption2, design: .rounded, weight: .semibold))

                Image(systemName: holding.changePercent >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 6))
            }
            .foregroundStyle(holding.changePercent >= 0 ? WidgetColors.profit : WidgetColors.loss)
            .frame(width: 65, alignment: .trailing)
        }
    }
}

// MARK: - Widget

struct HoldingsWidget: Widget {
    let kind = "HoldingsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HoldingsProvider()) { entry in
            HoldingsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("持仓列表")
        .description("显示主要持仓的实时价格和涨跌")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HoldingsWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: HoldingsEntry

    var body: some View {
        switch family {
        case .systemSmall:
            HoldingsWidgetSmallView(entry: entry)
        case .systemMedium:
            HoldingsWidgetMediumView(entry: entry)
        default:
            HoldingsWidgetMediumView(entry: entry)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    HoldingsWidget()
} timeline: {
    HoldingsEntry(date: Date(), data: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    HoldingsWidget()
} timeline: {
    HoldingsEntry(date: Date(), data: .placeholder)
}
