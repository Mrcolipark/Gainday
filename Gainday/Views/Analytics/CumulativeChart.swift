import SwiftUI
import Charts

struct CumulativeChart: View {
    let snapshots: [DailySnapshot]

    var body: some View {
        Chart(snapshots) { snapshot in
            LineMark(
                x: .value("Date", snapshot.date),
                y: .value("PnL", snapshot.cumulativePnL)
            )
            .foregroundStyle(
                (snapshots.last?.cumulativePnL ?? 0) >= 0
                    ? AppColors.profit
                    : AppColors.loss
            )
            .interpolationMethod(.monotone)

            AreaMark(
                x: .value("Date", snapshot.date),
                y: .value("PnL", snapshot.cumulativePnL)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        ((snapshots.last?.cumulativePnL ?? 0) >= 0
                            ? AppColors.profit
                            : AppColors.loss).opacity(0.2),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            // Zero line
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(AppColors.dividerColor.opacity(0.5))
                .lineStyle(StrokeStyle(dash: [4, 4]))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(AppColors.textSecondary)
                AxisGridLine()
                    .foregroundStyle(AppColors.dividerColor.opacity(0.3))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                    .foregroundStyle(AppColors.dividerColor.opacity(0.3))
                AxisValueLabel {
                    if let pnl = value.as(Double.self) {
                        Text(pnl.compactFormatted())
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
    }
}

#Preview {
    CumulativeChart(snapshots: [])
        .frame(height: 200)
        .padding()
        .background(AppColors.background)
        .preferredColorScheme(.dark)
}
