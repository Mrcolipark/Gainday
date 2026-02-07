import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct WeekCalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekCalendarEntry {
        WeekCalendarEntry(date: Date(), days: [], weekPnL: 0, baseCurrency: "JPY")
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekCalendarEntry) -> Void) {
        let result = WidgetDataLoader.loadWeekPnL()
        let weekPnL = result.days.reduce(0) { $0 + $1.pnl }
        completion(WeekCalendarEntry(date: Date(), days: result.days, weekPnL: weekPnL, baseCurrency: result.baseCurrency))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekCalendarEntry>) -> Void) {
        let result = WidgetDataLoader.loadWeekPnL()
        let weekPnL = result.days.reduce(0) { $0 + $1.pnl }
        let entry = WeekCalendarEntry(date: Date(), days: result.days, weekPnL: weekPnL, baseCurrency: result.baseCurrency)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct WeekCalendarEntry: TimelineEntry {
    let date: Date
    let days: [WidgetDayPnL]
    let weekPnL: Double
    let baseCurrency: String
}

// MARK: - Widget View

struct WeekCalendarWidgetView: View {
    let entry: WeekCalendarEntry

    private let weekdayLabels = ["月", "火", "水", "木", "金"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                let weekNum = Calendar.current.component(.weekOfMonth, from: entry.date)
                Text("\(entry.date.month)月 第\(weekNum)周")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                Spacer()
                Text(entry.weekPnL.currencyFormatted(code: entry.baseCurrency, showSign: true))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(entry.weekPnL >= 0 ? WidgetColors.changeBadgeGreen : WidgetColors.changeBadgeRed)
            }

            // Day cells
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    VStack(spacing: 4) {
                        Text(weekdayLabels[index])
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        if index < entry.days.count {
                            let day = entry.days[index]
                            RoundedRectangle(cornerRadius: 6)
                                .fill(pnlColor(percent: day.pnlPercent))
                                .frame(height: 32)
                                .overlay {
                                    Text(day.pnlPercent.percentFormatted())
                                        .font(.system(size: 7, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                        .minimumScaleFactor(0.5)
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 32)
                                .overlay {
                                    Text("--")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func pnlColor(percent: Double) -> Color {
        WidgetColors.pnlColor(percent: percent)
    }
}

// MARK: - Widget

struct WeekCalendarWidget: Widget {
    let kind = "WeekCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeekCalendarProvider()) { entry in
            WeekCalendarWidgetView(entry: entry)
        }
        .configurationDisplayName("本周日历")
        .description("显示本周每日盈亏")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    WeekCalendarWidget()
} timeline: {
    WeekCalendarEntry(date: Date(), days: [], weekPnL: 5200, baseCurrency: "JPY")
}
