import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct MarketIndicesProvider: TimelineProvider {
    func placeholder(in context: Context) -> MarketIndicesEntry {
        MarketIndicesEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MarketIndicesEntry) -> Void) {
        let data = WidgetDataLoader.loadMarketIndices()
        completion(MarketIndicesEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MarketIndicesEntry>) -> Void) {
        let data = WidgetDataLoader.loadMarketIndices()
        let entry = MarketIndicesEntry(date: Date(), data: data)
        // 15分钟刷新一次
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct MarketIndicesEntry: TimelineEntry {
    let date: Date
    let data: WidgetIndicesData
}

// MARK: - Widget Views

struct MarketIndicesWidgetSmallView: View {
    let entry: MarketIndicesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Show top 2 indices
            let indices = Array(entry.data.indices.prefix(2))
            if indices.isEmpty {
                Text("暂无数据")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(Array(indices.enumerated()), id: \.element.id) { idx, index in
                    SmallIndexCell(index: index)
                    if idx < indices.count - 1 {
                        Divider()
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct SmallIndexCell: View {
    let index: WidgetIndex

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Flag + Name
            HStack(spacing: 4) {
                Text(index.flag)
                    .font(.system(size: 10))
                Text(index.name)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .lineLimit(1)
            }

            // Value
            Text(formatValue(index.value))
                .font(.system(.subheadline, design: .rounded, weight: .bold))

            // Change
            HStack(spacing: 2) {
                Text(index.changePercent.percentFormatted())
                    .font(.system(.caption2, design: .rounded, weight: .semibold))

                Image(systemName: index.changePercent >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 6))
            }
            .foregroundStyle(index.changePercent >= 0 ? WidgetColors.profit : WidgetColors.loss)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 10000 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

struct MarketIndicesWidgetMediumView: View {
    let entry: MarketIndicesEntry

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 8) {
            // Show 4 indices in 2x2 grid
            let indices = Array(entry.data.indices.prefix(4))
            if indices.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(indices) { index in
                        MediumIndexCell(index: index)
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumIndexCell: View {
    let index: WidgetIndex

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Flag + Name
            HStack(spacing: 4) {
                Text(index.flag)
                    .font(.system(size: 12))
                Text(index.name)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .lineLimit(1)
            }

            // Value
            Text(formatValue(index.value))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Change
            HStack(spacing: 2) {
                Text(index.changePercent.percentFormatted())
                    .font(.system(.caption2, design: .rounded, weight: .semibold))

                Image(systemName: index.changePercent >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 6))
            }
            .foregroundStyle(index.changePercent >= 0 ? WidgetColors.profit : WidgetColors.loss)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 10000 {
            return String(format: "%.2f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Widget

struct MarketIndicesWidget: Widget {
    let kind = "MarketIndicesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MarketIndicesProvider()) { entry in
            MarketIndicesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("市场指数")
        .description("显示主要市场指数")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MarketIndicesWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MarketIndicesEntry

    var body: some View {
        switch family {
        case .systemSmall:
            MarketIndicesWidgetSmallView(entry: entry)
        case .systemMedium:
            MarketIndicesWidgetMediumView(entry: entry)
        default:
            MarketIndicesWidgetMediumView(entry: entry)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    MarketIndicesWidget()
} timeline: {
    MarketIndicesEntry(date: Date(), data: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    MarketIndicesWidget()
} timeline: {
    MarketIndicesEntry(date: Date(), data: .placeholder)
}
