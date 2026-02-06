import SwiftUI

/// 月度统计栏 - 统一设计语言
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

    private var avgPnLPercent: Double {
        guard !snapshots.isEmpty else { return 0 }
        return snapshots.reduce(0.0) { $0 + $1.dailyPnLPercent } / Double(snapshots.count)
    }

    var body: some View {
        VStack(spacing: 16) {
            // 头部：标题和总盈亏
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill((totalPnL >= 0 ? AppColors.profit : AppColors.loss).opacity(0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(totalPnL >= 0 ? AppColors.profit : AppColors.loss)
                    }

                    Text("月度汇总")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }

                Spacer()

                Text(totalPnL.currencyFormatted(code: baseCurrency, showSign: true))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(totalPnL >= 0 ? AppColors.profit : AppColors.loss)
            }

            Divider()
                .background(AppColors.dividerColor)

            // 统计数据网格
            HStack(spacing: 0) {
                MonthStatItem(
                    icon: "arrow.up.circle.fill",
                    iconColor: AppColors.profit,
                    title: "盈利",
                    value: "\(profitDays)天",
                    valueColor: AppColors.profit
                )

                verticalDivider

                MonthStatItem(
                    icon: "arrow.down.circle.fill",
                    iconColor: AppColors.loss,
                    title: "亏损",
                    value: "\(lossDays)天",
                    valueColor: AppColors.loss
                )

                verticalDivider

                MonthStatItem(
                    icon: "target",
                    iconColor: winRate >= 50 ? AppColors.profit : AppColors.loss,
                    title: "胜率",
                    value: String(format: "%.1f%%", winRate),
                    valueColor: winRate >= 50 ? AppColors.profit : AppColors.loss
                )

                if !snapshots.isEmpty {
                    verticalDivider

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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(AppColors.dividerColor)
            .frame(width: 1, height: 40)
    }
}

// MARK: - 统计项

private struct MonthStatItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MonthStatsBar(snapshots: [], baseCurrency: "JPY")
        .padding()
        .background(AppColors.background)
        .preferredColorScheme(.dark)
}
