import SwiftUI
import Charts

/// Mini 价格走势图 - 用于 Basic 视图模式
struct MiniSparkline: View {
    let prices: [Double]
    let isPositive: Bool

    init(prices: [Double], change: Double = 0) {
        self.prices = prices
        self.isPositive = change >= 0
    }

    var body: some View {
        if prices.count >= 2 {
            Chart {
                ForEach(Array(prices.enumerated()), id: \.offset) { index, price in
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Price", price)
                    )
                    .foregroundStyle(isPositive ? Color.green : Color.red)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", index),
                        yStart: .value("Min", prices.min() ?? 0),
                        yEnd: .value("Price", price)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                (isPositive ? Color.green : Color.red).opacity(0.2),
                                (isPositive ? Color.green : Color.red).opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartYScale(domain: (prices.min() ?? 0)...(prices.max() ?? 1))
        } else {
            // 无数据时显示占位
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
        }
    }
}

/// 带加载状态的 Mini Sparkline
struct SparklineView: View {
    let symbol: String
    let change: Double
    @State private var prices: [Double] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                shimmerPlaceholder
            } else if prices.isEmpty {
                noDataPlaceholder
            } else {
                MiniSparkline(prices: prices, change: change)
            }
        }
        .frame(width: 60, height: 28)
        .task {
            await loadPrices()
        }
    }

    private var shimmerPlaceholder: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.1))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.3),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: -60)
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isLoading)
            }
    }

    private var noDataPlaceholder: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.08))
            .overlay {
                Text("--")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
    }

    private func loadPrices() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 获取最近 5 天的收盘价作为 sparkline 数据
            let chartData = try await MarketDataService.shared.fetchChartData(
                symbol: symbol,
                interval: "1d",
                range: "5d"
            )
            prices = chartData.map { $0.close }
        } catch {
            prices = []
        }
    }
}

// MARK: - Simulated Sparkline for Preview

/// 用于预览的模拟价格数据
extension MiniSparkline {
    static func simulated(trend: Trend) -> MiniSparkline {
        let base: Double = 100
        var prices: [Double] = []

        for i in 0..<20 {
            let noise = Double.random(in: -2...2)
            switch trend {
            case .up:
                prices.append(base + Double(i) * 0.5 + noise)
            case .down:
                prices.append(base - Double(i) * 0.5 + noise)
            case .flat:
                prices.append(base + noise)
            }
        }

        return MiniSparkline(prices: prices, change: trend == .up ? 1 : (trend == .down ? -1 : 0))
    }

    enum Trend {
        case up, down, flat
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("上涨")
            MiniSparkline.simulated(trend: .up)
                .frame(width: 60, height: 28)
        }

        HStack {
            Text("下跌")
            MiniSparkline.simulated(trend: .down)
                .frame(width: 60, height: 28)
        }

        HStack {
            Text("横盘")
            MiniSparkline.simulated(trend: .flat)
                .frame(width: 60, height: 28)
        }
    }
    .padding()
}
