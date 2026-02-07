import SwiftUI

/// 简洁的折线走势图 - 用于详情页
struct SimpleLineChart: View {
    let data: [PriceCacheData]
    let isPositive: Bool

    private var prices: [Double] { data.map(\.close) }
    private var minPrice: Double { prices.min() ?? 0 }
    private var maxPrice: Double { prices.max() ?? 0 }

    var body: some View {
        if prices.isEmpty || maxPrice <= minPrice {
            Text("暂无数据".localized)
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 4) {
                // Y轴标签
                VStack {
                    Text(formatPrice(maxPrice))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                    Text(formatPrice((maxPrice + minPrice) / 2))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                    Text(formatPrice(minPrice))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .frame(width: 45)

                // 图表
                GeometryReader { geo in
                    let range = maxPrice - minPrice
                    let stepX = geo.size.width / CGFloat(max(1, prices.count - 1))

                    ZStack {
                        // 网格线
                        VStack {
                            ForEach(0..<3, id: \.self) { _ in
                                Divider().opacity(0.2)
                                Spacer()
                            }
                        }

                        // 折线
                        Path { path in
                            for (index, price) in prices.enumerated() {
                                let x = CGFloat(index) * stepX
                                let y = geo.size.height - ((price - minPrice) / range) * geo.size.height

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(isPositive ? AppColors.profit : AppColors.loss, lineWidth: 1.5)
                    }
                }
            }
        }
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 10000 {
            return String(format: "%.0f", price)
        } else if price >= 100 {
            return String(format: "%.1f", price)
        } else {
            return String(format: "%.2f", price)
        }
    }
}

#Preview {
    SimpleLineChart(
        data: [],
        isPositive: true
    )
    .frame(height: 180)
    .padding()
    .preferredColorScheme(.dark)
}
