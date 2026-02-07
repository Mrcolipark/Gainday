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

// MARK: - Small Widget View

struct DailyPnLSmallView: View {
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

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: entry.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("今日盈亏".widgetLocalized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(timeString)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            // Main PnL value
            Text(entry.data.dailyPnL.compactFormatted(code: entry.data.baseCurrency, showSign: true))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(pnlColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 6)

            // Percentage badge
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

// MARK: - Medium Widget View

struct DailyPnLMediumView: View {
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

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: entry.date)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: PnL
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("今日盈亏".widgetLocalized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                Text(entry.data.dailyPnL.compactFormatted(code: entry.data.baseCurrency, showSign: true))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(pnlColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

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
            }

            Divider()

            // Right: Total assets
            VStack(alignment: .leading, spacing: 6) {
                Text("总资产".widgetLocalized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(entry.data.totalValue.compactFormatted(code: entry.data.baseCurrency))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                Text(timeString)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Empty State View

struct DailyPnLEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)

            Text("今日盈亏".widgetLocalized)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Entry View

struct DailyPnLWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: DailyPnLEntry

    var body: some View {
        if entry.data.isEmpty {
            DailyPnLEmptyView()
        } else {
            switch family {
            case .systemMedium:
                DailyPnLMediumView(entry: entry)
            default:
                DailyPnLSmallView(entry: entry)
            }
        }
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview("Small - 浅色") {
    DailyPnLSmallView(entry: DailyPnLEntry(date: Date(), data: .placeholder))
        .containerBackground(.fill.tertiary, for: .widget)
        .previewContext(WidgetPreviewContext(family: .systemSmall))
        .environment(\.colorScheme, .light)
}

#Preview("Small - 深色") {
    DailyPnLSmallView(entry: DailyPnLEntry(date: Date(), data: .placeholder))
        .containerBackground(.fill.tertiary, for: .widget)
        .previewContext(WidgetPreviewContext(family: .systemSmall))
        .environment(\.colorScheme, .dark)
}

#Preview("Medium") {
    DailyPnLMediumView(entry: DailyPnLEntry(date: Date(), data: .placeholder))
        .containerBackground(.fill.tertiary, for: .widget)
        .previewContext(WidgetPreviewContext(family: .systemMedium))
}

#Preview("Empty") {
    DailyPnLEmptyView()
        .containerBackground(.fill.tertiary, for: .widget)
        .previewContext(WidgetPreviewContext(family: .systemSmall))
}
