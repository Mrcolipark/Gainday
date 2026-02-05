import SwiftUI
import Charts

struct RankingChart: View {
    let holdings: [Holding]

    private struct RankingItem: Identifiable {
        let id: UUID
        let name: String
        let pnl: Double
    }

    private var rankingData: [RankingItem] {
        holdings
            .map { holding in
                let unrealized = (0 - holding.averageCost) * holding.totalQuantity
                return RankingItem(id: holding.id, name: holding.name, pnl: unrealized)
            }
            .sorted { $0.pnl > $1.pnl }
    }

    var body: some View {
        Chart(rankingData) { item in
            BarMark(
                x: .value("PnL", item.pnl),
                y: .value("Name", item.name)
            )
            .foregroundStyle(item.pnl >= 0 ? AppColors.profit : AppColors.loss)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let pnl = value.as(Double.self) {
                        Text(pnl.compactFormatted())
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let name = value.as(String.self) {
                        Text(name)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

#Preview {
    RankingChart(holdings: [])
        .frame(height: 200)
        .padding()
}
