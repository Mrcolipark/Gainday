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

    private var isProfit: Bool {
        entry.data.dailyPnL >= 0
    }

    private var pnlColor: Color {
        isProfit ? WidgetColors.profit : WidgetColors.loss
    }

    private var percentString: String {
        let percent = entry.data.dailyPnLPercent
        let absPercent = abs(percent)
        if absPercent >= 10 {
            return String(format: "%+.1f%%", percent)
        } else {
            return String(format: "%+.2f%%", percent)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("今日盈亏".widgetLocalized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            // Main PnL value - 使用紧凑格式避免截断
            Text(entry.data.dailyPnL.compactFormatted(code: entry.data.baseCurrency, showSign: true))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(pnlColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 6)

            // Percentage badge - 智能格式化避免截断
            HStack(spacing: 3) {
                Image(systemName: isProfit ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                Text(percentString)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(pnlColor)
            )

            Spacer()

            // Footer - Total assets
            HStack(spacing: 3) {
                Text("总资产".widgetLocalized)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(entry.data.totalValue.compactFormatted(code: entry.data.baseCurrency))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget

struct DailyPnLWidget: Widget {
    let kind = "DailyPnLWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyPnLProvider()) { entry in
            DailyPnLWidgetView(entry: entry)
        }
        .configurationDisplayName("今日盈亏Widget".widgetLocalized)
        .description("显示今日盈亏和总资产".widgetLocalized)
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Previews

#Preview("浅色模式") {
    DailyPnLWidgetView(entry: DailyPnLEntry(date: Date(), data: .placeholder))
        .containerBackground(.fill.tertiary, for: .widget)
        .previewContext(WidgetPreviewContext(family: .systemSmall))
        .environment(\.colorScheme, .light)
}

#Preview("深色模式") {
    DailyPnLWidgetView(entry: DailyPnLEntry(date: Date(), data: .placeholder))
        .containerBackground(.fill.tertiary, for: .widget)
        .previewContext(WidgetPreviewContext(family: .systemSmall))
        .environment(\.colorScheme, .dark)
}

#Preview("浅色 - 亏损") {
    DailyPnLWidgetView(entry: DailyPnLEntry(date: Date(), data: WidgetPnLData(
        totalValue: 2_500_000,
        dailyPnL: -15_800,
        dailyPnLPercent: -0.63,
        baseCurrency: "JPY",
        date: Date()
    )))
    .containerBackground(.fill.tertiary, for: .widget)
    .previewContext(WidgetPreviewContext(family: .systemSmall))
    .environment(\.colorScheme, .light)
}

#Preview("深色 - 亏损") {
    DailyPnLWidgetView(entry: DailyPnLEntry(date: Date(), data: WidgetPnLData(
        totalValue: 2_500_000,
        dailyPnL: -15_800,
        dailyPnLPercent: -0.63,
        baseCurrency: "JPY",
        date: Date()
    )))
    .containerBackground(.fill.tertiary, for: .widget)
    .previewContext(WidgetPreviewContext(family: .systemSmall))
    .environment(\.colorScheme, .dark)
}
