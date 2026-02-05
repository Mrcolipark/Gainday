import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct DailyPnLProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyPnLEntry {
        DailyPnLEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyPnLEntry) -> Void) {
        let data = WidgetDataLoader.loadLatestPnL()
        completion(DailyPnLEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyPnLEntry>) -> Void) {
        let data = WidgetDataLoader.loadLatestPnL()
        let entry = DailyPnLEntry(date: Date(), data: data)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct DailyPnLEntry: TimelineEntry {
    let date: Date
    let data: WidgetPnLData
}

// MARK: - Widget View

struct DailyPnLWidgetView: View {
    let entry: DailyPnLEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: entry.data.dailyPnL >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(pnlColor)
                Text("今日")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(entry.data.dailyPnL.currencyFormatted(code: entry.data.baseCurrency, showSign: true))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(pnlColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(entry.data.dailyPnLPercent.percentFormatted())
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(pnlColor.opacity(0.8))

            Spacer()

            Text("总资产 \(entry.data.totalValue.compactFormatted(code: entry.data.baseCurrency))")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var pnlColor: Color {
        entry.data.dailyPnL >= 0 ? WidgetColors.changeBadgeGreen : WidgetColors.changeBadgeRed
    }
}

// MARK: - Widget

struct DailyPnLWidget: Widget {
    let kind = "DailyPnLWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyPnLProvider()) { entry in
            DailyPnLWidgetView(entry: entry)
        }
        .configurationDisplayName("今日盈亏")
        .description("显示今日盈亏和总资产")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    DailyPnLWidget()
} timeline: {
    DailyPnLEntry(date: Date(), data: .placeholder)
}
