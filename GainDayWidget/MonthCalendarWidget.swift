import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct MonthCalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthCalendarEntry {
        MonthCalendarEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthCalendarEntry) -> Void) {
        let data = WidgetDataLoader.loadMonthData()
        completion(MonthCalendarEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthCalendarEntry>) -> Void) {
        let data = WidgetDataLoader.loadMonthData()
        let entry = MonthCalendarEntry(date: Date(), data: data)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct MonthCalendarEntry: TimelineEntry {
    let date: Date
    let data: WidgetMonthData
}

// MARK: - Widget View

struct MonthCalendarWidgetView: View {
    let entry: MonthCalendarEntry
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdayLabels = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        VStack(spacing: 6) {
            // Header
            HStack {
                Text(entry.data.month.monthYearString)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                Spacer()
                Text(entry.data.totalPnL.currencyFormatted(code: entry.data.baseCurrency, showSign: true))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(entry.data.totalPnL >= 0 ? WidgetColors.changeBadgeGreen : WidgetColors.changeBadgeRed)
            }

            // Weekday headers
            HStack(spacing: 2) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 2) {
                let calendarDays = entry.data.month.calendarDays()
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        let pct = entry.data.days[date.startOfDay] ?? 0
                        let hasData = entry.data.days[date.startOfDay] != nil

                        RoundedRectangle(cornerRadius: 3)
                            .fill(hasData ? pnlColor(percent: pct) : Color.secondary.opacity(0.08))
                            .frame(height: 16)
                            .overlay {
                                Text(date.dayString)
                                    .font(.system(size: 7, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.8))
                            }
                    } else {
                        Color.clear
                            .frame(height: 16)
                    }
                }
            }

            // Footer stats
            HStack {
                Text("胜率 \(String(format: "%.1f", entry.data.winRate))%")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("盈\(entry.data.profitDays) 亏\(entry.data.lossDays)")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func pnlColor(percent: Double) -> Color {
        WidgetColors.pnlColor(percent: percent)
    }
}

// MARK: - Widget

struct MonthCalendarWidget: Widget {
    let kind = "MonthCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonthCalendarProvider()) { entry in
            MonthCalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("月历概览")
        .description("显示本月盈亏日历")
        .supportedFamilies([.systemLarge])
    }
}

#Preview(as: .systemLarge) {
    MonthCalendarWidget()
} timeline: {
    MonthCalendarEntry(date: Date(), data: .placeholder)
}
