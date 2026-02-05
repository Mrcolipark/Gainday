import SwiftUI

struct MonthStatsBar: View {
    let snapshots: [DailySnapshot]
    let baseCurrency: String

    private var totalPnL: Double {
        snapshots.reduce(0) { $0 + $1.dailyPnL }
    }

    private var profitDays: Int {
        snapshots.filter { $0.dailyPnL > 0 }.count
    }

    private var lossDays: Int {
        snapshots.filter { $0.dailyPnL < 0 }.count
    }

    private var winRate: Double {
        let total = profitDays + lossDays
        guard total > 0 else { return 0 }
        return Double(profitDays) / Double(total) * 100
    }

    var body: some View {
        AccentGlassCard(color: totalPnL >= 0 ? .green : .red) {
            VStack(spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.caption)
                            .foregroundStyle(totalPnL >= 0 ? .green : .red)
                        Text("月度汇总")
                            .font(.headline)
                    }
                    Spacer()
                    PnLText(totalPnL, currencyCode: baseCurrency, style: .small)
                }

                Rectangle()
                    .fill(AppColors.dividerColor)
                    .frame(height: 1)

                HStack(spacing: 0) {
                    MonthStatItem(
                        icon: "arrow.up.circle.fill",
                        iconColor: AppColors.profit,
                        title: "盈利",
                        value: "\(profitDays)天",
                        valueColor: AppColors.profit
                    )
                    MonthStatItem(
                        icon: "arrow.down.circle.fill",
                        iconColor: AppColors.loss,
                        title: "亏损",
                        value: "\(lossDays)天",
                        valueColor: AppColors.loss
                    )
                    MonthStatItem(
                        icon: "target",
                        iconColor: winRate >= 50 ? AppColors.profit : AppColors.loss,
                        title: "胜率",
                        value: String(format: "%.1f%%", winRate),
                        valueColor: winRate >= 50 ? AppColors.profit : AppColors.loss
                    )

                    if !snapshots.isEmpty {
                        let totalPnLPercent = snapshots.reduce(0.0) { $0 + $1.dailyPnLPercent }
                        let avgPnLPercent = totalPnLPercent / Double(snapshots.count)
                        MonthStatItem(
                            icon: "chart.line.flattrend.xyaxis",
                            iconColor: avgPnLPercent >= 0 ? AppColors.profit : AppColors.loss,
                            title: "日均",
                            value: String(format: "%.2f%%", avgPnLPercent),
                            valueColor: avgPnLPercent >= 0 ? AppColors.profit : AppColors.loss
                        )
                    }
                }
            }
        }
    }
}

private struct MonthStatItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MonthStatsBar(snapshots: [], baseCurrency: "JPY")
        .padding()
}
