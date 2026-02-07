import SwiftUI
import Charts

/// Apple Stocks 风格的交互式股票图表
/// 支持拖动查看价格、垂直指示线、触觉反馈、双指缩放
struct InteractiveStockChart: View {
    let data: [PriceCacheData]
    let currency: String

    @State private var selectedDate: Date?
    @State private var selectedPrice: Double?
    @State private var magnifyScale: CGFloat = 1.0
    @State private var lastMagnifyScale: CGFloat = 1.0
    @Binding var isInteracting: Bool

    private var isPositive: Bool {
        guard let first = data.first?.close, let last = data.last?.close else { return true }
        return last >= first
    }

    private var lineColor: Color {
        isPositive ? AppColors.profit : AppColors.loss
    }

    private var minPrice: Double {
        data.map(\.close).min() ?? 0
    }

    private var maxPrice: Double {
        data.map(\.close).max() ?? 0
    }

    // 根据缩放计算可见数据范围
    private var visibleData: [PriceCacheData] {
        guard !data.isEmpty else { return [] }
        let totalCount = data.count
        let visibleCount = max(10, Int(Double(totalCount) / Double(magnifyScale)))
        let startIndex = max(0, totalCount - visibleCount)
        return Array(data[startIndex..<totalCount])
    }

    private var visibleMinPrice: Double {
        visibleData.map(\.close).min() ?? 0
    }

    private var visibleMaxPrice: Double {
        visibleData.map(\.close).max() ?? 0
    }

    init(data: [PriceCacheData], currency: String = "USD", isInteracting: Binding<Bool> = .constant(false)) {
        self.data = data
        self.currency = currency
        self._isInteracting = isInteracting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 选中时显示的价格信息
            priceHeader

            // 图表
            if data.count >= 2 {
                chartView
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                emptyState
            }
        }
    }

    // MARK: - 价格头部

    private var priceHeader: some View {
        Group {
            if let price = selectedPrice, let date = selectedDate {
                // 交互时显示选中的价格
                VStack(alignment: .leading, spacing: 2) {
                    Text(price.currencyFormatted(code: currency))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())

                    Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .animation(.easeInOut(duration: 0.1), value: price)
            } else {
                // 默认显示最新价格
                if let lastPrice = data.last?.close, let lastDate = data.last?.date {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lastPrice.currencyFormatted(code: currency))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)

                        Text(lastDate.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .frame(height: 50)
    }

    // MARK: - 图表视图

    private var chartView: some View {
        let priceRange = visibleMaxPrice - visibleMinPrice
        let padding = priceRange * 0.05
        let yMin = visibleMinPrice - padding
        let yMax = visibleMaxPrice + padding

        return Chart(visibleData, id: \.date) { point in
            // 渐变填充 - 使用 yStart 防止超出
            AreaMark(
                x: .value("Date", point.date),
                yStart: .value("Min", yMin),
                yEnd: .value("Price", point.close)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [lineColor.opacity(0.2), lineColor.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            // 折线
            LineMark(
                x: .value("Date", point.date),
                y: .value("Price", point.close)
            )
            .foregroundStyle(lineColor)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.monotone)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: xAxisStride)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatXAxisDate(date))
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(AppColors.dividerColor)
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(formatAxisPrice(price))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
        }
        .chartYScale(domain: yMin ... yMax)
        .chartOverlay { chartProxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(chartProxy: chartProxy, geometry: geometry))
                    .gesture(magnifyGesture)

                // 垂直指示线和选中点
                if let selectedDate {
                    selectionIndicator(chartProxy: chartProxy, geometry: geometry)
                }
            }
        }
    }

    // MARK: - X轴时间间隔

    private var xAxisStride: Calendar.Component {
        let count = visibleData.count
        if count <= 7 {
            return .day
        } else if count <= 31 {
            return .weekOfYear
        } else if count <= 90 {
            return .month
        } else {
            return .month
        }
    }

    private func formatXAxisDate(_ date: Date) -> String {
        let count = visibleData.count
        if count <= 7 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        } else if count <= 31 {
            return date.formatted(.dateTime.day())
        } else {
            return date.formatted(.dateTime.month(.abbreviated))
        }
    }

    // MARK: - 手势

    private func dragGesture(chartProxy: ChartProxy, geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleDragChange(value: value, chartProxy: chartProxy, geometry: geometry)
            }
            .onEnded { _ in
                handleDragEnd()
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastMagnifyScale * value.magnification
                magnifyScale = min(max(newScale, 1.0), 5.0) // 限制 1x - 5x
            }
            .onEnded { _ in
                lastMagnifyScale = magnifyScale
                // 缩放结束触觉反馈
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
    }

    // MARK: - 选中指示器

    @ViewBuilder
    private func selectionIndicator(chartProxy: ChartProxy, geometry: GeometryProxy) -> some View {
        if let selectedDate,
           let xPosition = chartProxy.position(forX: selectedDate) {

            let plotFrame = geometry[chartProxy.plotFrame!]

            // 垂直线
            Path { path in
                path.move(to: CGPoint(x: xPosition, y: 0))
                path.addLine(to: CGPoint(x: xPosition, y: plotFrame.height))
            }
            .stroke(AppColors.textSecondary.opacity(0.6), style: StrokeStyle(lineWidth: 1))

            // 选中点
            if let selectedPrice,
               let yPosition = chartProxy.position(forY: selectedPrice) {
                // 外圈光晕
                Circle()
                    .fill(lineColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .position(x: xPosition, y: yPosition)

                // 内圈
                Circle()
                    .fill(lineColor)
                    .frame(width: 10, height: 10)
                    .position(x: xPosition, y: yPosition)

                // 白色边框
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: 10, height: 10)
                    .position(x: xPosition, y: yPosition)
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.textTertiary)
            Text("暂无图表数据".localized)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 手势处理

    private func handleDragChange(value: DragGesture.Value, chartProxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = chartProxy.plotFrame else { return }
        let frame = geometry[plotFrame]
        let x = value.location.x - frame.origin.x

        guard x >= 0, x <= frame.width else { return }

        if let date: Date = chartProxy.value(atX: x) {
            // 找到最接近的数据点
            if let closestPoint = findClosestPoint(to: date) {
                let previousDate = selectedDate
                selectedDate = closestPoint.date
                selectedPrice = closestPoint.close
                isInteracting = true

                // 触觉反馈 - 只在切换到新数据点时
                if previousDate != closestPoint.date {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        }
    }

    private func handleDragEnd() {
        withAnimation(.easeOut(duration: 0.2)) {
            selectedDate = nil
            selectedPrice = nil
            isInteracting = false
        }
    }

    private func findClosestPoint(to date: Date) -> PriceCacheData? {
        visibleData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    private func formatAxisPrice(_ price: Double) -> String {
        if price >= 10000 {
            return String(format: "%.0f", price)
        } else if price >= 100 {
            return String(format: "%.1f", price)
        } else {
            return String(format: "%.2f", price)
        }
    }
}

// MARK: - 简化版本（不需要绑定）

extension InteractiveStockChart {
    /// 简化构造器，不需要 isInteracting 绑定
    static func simple(data: [PriceCacheData], currency: String = "USD") -> InteractiveStockChart {
        InteractiveStockChart(data: data, currency: currency, isInteracting: .constant(false))
    }
}

#Preview {
    VStack {
        InteractiveStockChart(
            data: [],
            currency: "USD"
        )
        .frame(height: 250)
        .padding()
        .background(AppColors.cardSurface)
    }
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
