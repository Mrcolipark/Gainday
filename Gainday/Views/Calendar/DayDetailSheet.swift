import SwiftUI

struct DayDetailSheet: View {
    let date: Date
    let snapshot: DailySnapshot?

    @State private var animateContent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let snapshot = snapshot {
                        // Daily P&L Summary
                        pnlSummaryCard(snapshot)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 15)

                        // Breakdown by asset type
                        let breakdown = snapshot.breakdown
                        if !breakdown.isEmpty {
                            breakdownCard(breakdown)
                                .opacity(animateContent ? 1 : 0)
                                .offset(y: animateContent ? 0 : 10)
                        }
                    } else {
                        // No data
                        emptyState
                    }
                }
                .padding()
            }
            .navigationTitle(date.shortDateString)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    animateContent = true
                }
            }
        }
    }

    // MARK: - P&L Summary

    private func pnlSummaryCard(_ snapshot: DailySnapshot) -> some View {
        AccentGlassCard(color: snapshot.dailyPnL >= 0 ? .green : .red) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.circle.fill")
                            .font(.caption)
                            .foregroundStyle(snapshot.dailyPnL >= 0 ? .green : .red)
                        Text("当日盈亏")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    PnLPercentText(snapshot.dailyPnLPercent, style: .caption)
                }

                PnLText(snapshot.dailyPnL, style: .large)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .secondary.opacity(0.15), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)

                HStack(spacing: 0) {
                    DayStatColumn(
                        icon: "chart.bar.fill",
                        iconColor: .blue,
                        title: "市值",
                        value: snapshot.totalValue.currencyFormatted()
                    )
                    DayStatColumn(
                        icon: "banknote",
                        iconColor: .orange,
                        title: "成本",
                        value: snapshot.totalCost.currencyFormatted()
                    )
                    DayStatColumn(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: snapshot.cumulativePnL >= 0 ? .green : .red,
                        title: "累计盈亏",
                        value: snapshot.cumulativePnL.currencyFormatted(showSign: true)
                    )
                }
            }
        }
    }

    // MARK: - Breakdown

    private func breakdownCard(_ breakdown: [AssetBreakdown]) -> some View {
        GlassCard(tint: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("分类明细")
                        .font(.headline)
                }

                ForEach(Array(breakdown.enumerated()), id: \.element.assetType) { index, item in
                    let assetType = AssetType(rawValue: item.assetType) ?? .stock
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(assetType.color.opacity(0.12))
                                .frame(width: 30, height: 30)
                            Image(systemName: assetType.iconName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(assetType.color)
                        }
                        Text(assetType.displayName)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.value.currencyFormatted(code: item.currency))
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .monospacedDigit()
                            PnLText(item.pnl, currencyCode: item.currency, style: .caption)
                        }
                    }
                    .staggeredAppearance(index: index)

                    if index < breakdown.count - 1 {
                        Divider().opacity(0.3)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        GlassCard(tint: .blue) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 64, height: 64)
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue.opacity(0.6))
                }
                Text("该日无数据")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("持仓数据在交易日收盘后生成")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .padding(.top, 20)
    }
}

// MARK: - Day Stat Column

private struct DayStatColumn: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DayDetailSheet(date: Date(), snapshot: nil)
}
