import SwiftUI
import Charts

struct MonthlyBarChart: View {
    let snapshots: [DailySnapshot]

    private struct MonthlyPnL: Identifiable {
        let id = UUID()
        let month: Date
        let pnl: Double
        let label: String
    }

    private var monthlyData: [MonthlyPnL] {
        var grouped: [String: (date: Date, pnl: Double)] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        for snapshot in snapshots {
            let key = formatter.string(from: snapshot.date)
            if grouped[key] != nil {
                grouped[key]!.pnl += snapshot.dailyPnL
            } else {
                grouped[key] = (date: snapshot.date.startOfMonth, pnl: snapshot.dailyPnL)
            }
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "M月"

        return grouped
            .map { MonthlyPnL(month: $0.value.date, pnl: $0.value.pnl, label: displayFormatter.string(from: $0.value.date)) }
            .sorted { $0.month < $1.month }
            .suffix(12)
            .map { $0 }
    }

    var body: some View {
        Chart(monthlyData) { item in
            BarMark(
                x: .value("Month", item.label),
                y: .value("PnL", item.pnl)
            )
            .foregroundStyle(item.pnl >= 0 ? AppColors.profit : AppColors.loss)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                    .foregroundStyle(AppColors.dividerColor.opacity(0.5))
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
    MonthlyBarChart(snapshots: [])
        .frame(height: 200)
        .padding()
        .background(AppColors.background)
        .preferredColorScheme(.dark)
}
