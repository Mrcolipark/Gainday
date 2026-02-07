import SwiftUI
import Charts
import UIKit

/// Apple Stocks 风格的交互式股票图表
/// 支持单指查看价格、双指比较区间、触觉反馈
/// 使用索引作为X轴避免周末间隙
struct InteractiveStockChart: View {
    let data: [PriceCacheData]
    let currency: String
    let timeRange: TimeRange

    @State private var selectedIndex: Int?
    @State private var rangeSelection: RangeSelection?
    @Binding var isInteracting: Bool

    struct RangeSelection {
        var startIndex: Int
        var endIndex: Int
        var startDate: Date
        var endDate: Date
        var startPrice: Double
        var endPrice: Double

        var priceDiff: Double { endPrice - startPrice }
        var percentDiff: Double {
            guard startPrice > 0 else { return 0 }
            return ((endPrice - startPrice) / startPrice) * 100
        }
        var isPositive: Bool { priceDiff >= 0 }
    }

    /// 索引化的数据点（用于图表绑定）
    private struct IndexedPoint: Identifiable {
        let id: Int
        let index: Int
        let date: Date
        let close: Double
    }

    /// 过滤无效数据点（价格为0或负数）
    private var validData: [PriceCacheData] {
        data.filter { $0.close > 0 }
    }

    /// 转换为索引化数据
    private var indexedData: [IndexedPoint] {
        validData.enumerated().map { IndexedPoint(id: $0.offset, index: $0.offset, date: $0.element.date, close: $0.element.close) }
    }

    private var isPositive: Bool {
        guard let first = validData.first?.close, let last = validData.last?.close else { return true }
        return last >= first
    }

    private var lineColor: Color {
        if let range = rangeSelection {
            return range.isPositive ? AppColors.profit : AppColors.loss
        }
        return isPositive ? AppColors.profit : AppColors.loss
    }

    private var visibleMinPrice: Double {
        validData.map(\.close).min() ?? 0
    }

    private var visibleMaxPrice: Double {
        validData.map(\.close).max() ?? 0
    }

    init(data: [PriceCacheData], currency: String = "USD", timeRange: TimeRange = .threeMonths, isInteracting: Binding<Bool> = .constant(false)) {
        self.data = data
        self.currency = currency
        self.timeRange = timeRange
        self._isInteracting = isInteracting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 价格信息头部
            priceHeader

            // 图表
            if validData.count >= 2 {
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
            if let range = rangeSelection {
                rangeSelectionHeader(range)
            } else if let index = selectedIndex, index < validData.count {
                let point = validData[index]
                singleSelectionHeader(price: point.close, date: point.date)
            } else {
                defaultHeader
            }
        }
        .frame(height: 50)
    }

    private func rangeSelectionHeader(_ range: RangeSelection) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(range.priceDiff.currencyFormatted(code: currency, showSign: true))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(range.isPositive ? AppColors.profit : AppColors.loss)

                Text(String(format: "%@%.2f%%", range.isPositive ? "+" : "", range.percentDiff))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(range.isPositive ? AppColors.profit : AppColors.loss)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(range.startDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
                Text("→")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textTertiary)
                Text(range.endDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func singleSelectionHeader(price: Double, date: Date) -> some View {
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
    }

    private var defaultHeader: some View {
        Group {
            if let lastPrice = validData.last?.close, let lastDate = validData.last?.date {
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

    // MARK: - 图表视图

    private var chartView: some View {
        let priceRange = visibleMaxPrice - visibleMinPrice
        let padding = priceRange * 0.05
        let yMin = visibleMinPrice - padding
        let yMax = visibleMaxPrice + padding

        // 使用索引作为 X 轴避免周末间隙
        return Chart(indexedData) { point in
            // 渐变填充
            AreaMark(
                x: .value("Index", point.index),
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
                x: .value("Index", point.index),
                y: .value("Price", point.close)
            )
            .foregroundStyle(lineColor)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.monotone)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let index = value.as(Int.self), index >= 0, index < validData.count {
                        Text(formatXAxisDate(validData[index].date))
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
        .chartXScale(domain: 0 ... max(1, validData.count - 1))
        .chartOverlay { chartProxy in
            GeometryReader { geometry in
                // 使用 UIKit 手势识别器支持多点触控
                MultiTouchGestureView(
                    onSingleTouch: { location in
                        handleSingleTouch(location: location, chartProxy: chartProxy, geometry: geometry)
                    },
                    onDoubleTouch: { location1, location2 in
                        handleDoubleTouch(location1: location1, location2: location2, chartProxy: chartProxy, geometry: geometry)
                    },
                    onTouchEnded: {
                        handleTouchEnd()
                    }
                )

                // 单指选中指示器
                if let index = selectedIndex, rangeSelection == nil {
                    singleSelectionIndicator(index: index, chartProxy: chartProxy, geometry: geometry)
                }

                // 双指区间指示器
                if let range = rangeSelection {
                    rangeSelectionIndicator(range: range, chartProxy: chartProxy, geometry: geometry)
                }
            }
        }
    }

    // MARK: - 指示器

    @ViewBuilder
    private func singleSelectionIndicator(index: Int, chartProxy: ChartProxy, geometry: GeometryProxy) -> some View {
        if index < validData.count,
           let xPosition = chartProxy.position(forX: index),
           let plotFrame = chartProxy.plotFrame {

            let frame = geometry[plotFrame]
            let price = validData[index].close

            // 垂直线
            Path { path in
                path.move(to: CGPoint(x: xPosition, y: 0))
                path.addLine(to: CGPoint(x: xPosition, y: frame.height))
            }
            .stroke(AppColors.textSecondary.opacity(0.6), style: StrokeStyle(lineWidth: 1))

            // 选中点
            if let yPosition = chartProxy.position(forY: price) {
                Circle()
                    .fill(lineColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .position(x: xPosition, y: yPosition)

                Circle()
                    .fill(lineColor)
                    .frame(width: 10, height: 10)
                    .position(x: xPosition, y: yPosition)

                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: 10, height: 10)
                    .position(x: xPosition, y: yPosition)
            }
        }
    }

    @ViewBuilder
    private func rangeSelectionIndicator(range: RangeSelection, chartProxy: ChartProxy, geometry: GeometryProxy) -> some View {
        if let startX = chartProxy.position(forX: range.startIndex),
           let endX = chartProxy.position(forX: range.endIndex),
           let plotFrame = chartProxy.plotFrame {

            let frame = geometry[plotFrame]
            let minX = min(startX, endX)
            let maxX = max(startX, endX)

            // 高亮区域
            Rectangle()
                .fill(lineColor.opacity(0.1))
                .frame(width: maxX - minX)
                .frame(height: frame.height)
                .position(x: (minX + maxX) / 2, y: frame.height / 2)

            // 起始线
            Path { path in
                path.move(to: CGPoint(x: startX, y: 0))
                path.addLine(to: CGPoint(x: startX, y: frame.height))
            }
            .stroke(lineColor, style: StrokeStyle(lineWidth: 1.5))

            // 结束线
            Path { path in
                path.move(to: CGPoint(x: endX, y: 0))
                path.addLine(to: CGPoint(x: endX, y: frame.height))
            }
            .stroke(lineColor, style: StrokeStyle(lineWidth: 1.5))

            // 起始点
            if let startY = chartProxy.position(forY: range.startPrice) {
                Circle()
                    .fill(lineColor)
                    .frame(width: 10, height: 10)
                    .position(x: startX, y: startY)
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: 10, height: 10)
                    .position(x: startX, y: startY)
            }

            // 结束点
            if let endY = chartProxy.position(forY: range.endPrice) {
                Circle()
                    .fill(lineColor)
                    .frame(width: 10, height: 10)
                    .position(x: endX, y: endY)
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: 10, height: 10)
                    .position(x: endX, y: endY)
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

    // MARK: - 触摸处理

    private func handleSingleTouch(location: CGPoint, chartProxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = chartProxy.plotFrame else { return }
        let frame = geometry[plotFrame]
        let x = location.x - frame.origin.x

        guard x >= 0, x <= frame.width else { return }

        if let index: Int = chartProxy.value(atX: x) {
            let clampedIndex = max(0, min(index, validData.count - 1))
            let previousIndex = selectedIndex

            selectedIndex = clampedIndex
            rangeSelection = nil
            isInteracting = true

            if previousIndex != clampedIndex {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func handleDoubleTouch(location1: CGPoint, location2: CGPoint, chartProxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = chartProxy.plotFrame else { return }
        let frame = geometry[plotFrame]

        let x1 = location1.x - frame.origin.x
        let x2 = location2.x - frame.origin.x

        guard x1 >= 0, x1 <= frame.width, x2 >= 0, x2 <= frame.width else { return }

        if let index1: Int = chartProxy.value(atX: x1),
           let index2: Int = chartProxy.value(atX: x2) {

            let clamped1 = max(0, min(index1, validData.count - 1))
            let clamped2 = max(0, min(index2, validData.count - 1))

            let (startIdx, endIdx) = clamped1 < clamped2 ? (clamped1, clamped2) : (clamped2, clamped1)

            let newRange = RangeSelection(
                startIndex: startIdx,
                endIndex: endIdx,
                startDate: validData[startIdx].date,
                endDate: validData[endIdx].date,
                startPrice: validData[startIdx].close,
                endPrice: validData[endIdx].close
            )

            if rangeSelection?.startIndex != newRange.startIndex || rangeSelection?.endIndex != newRange.endIndex {
                rangeSelection = newRange
                selectedIndex = nil
                isInteracting = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func handleTouchEnd() {
        withAnimation(.easeOut(duration: 0.2)) {
            selectedIndex = nil
            rangeSelection = nil
            isInteracting = false
        }
    }

    /// 根据时间范围格式化横轴日期（Apple Stocks 风格）
    private func formatXAxisDate(_ date: Date) -> String {
        switch timeRange {
        case .day:
            // 1D: 显示时间 (10:30)
            return date.formatted(.dateTime.hour().minute())
        case .week:
            // 1W: 显示星期 (Mon, Tue)
            return date.formatted(.dateTime.weekday(.abbreviated))
        case .month:
            // 1M: 显示日期 (5, 10, 15)
            return date.formatted(.dateTime.day())
        case .threeMonths, .sixMonths:
            // 3M/6M: 显示月日 (Jan 5)
            return date.formatted(.dateTime.month(.abbreviated).day())
        case .year:
            // 1Y: 显示月份 (Jan, Feb)
            return date.formatted(.dateTime.month(.abbreviated))
        case .twoYears, .fiveYears:
            // 2Y/5Y: 显示年月 (Jan '24)
            return date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
        case .all:
            // ALL: 显示年份 (2023, 2024)
            return date.formatted(.dateTime.year())
        }
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

// MARK: - 多点触控手势视图

struct MultiTouchGestureView: UIViewRepresentable {
    let onSingleTouch: (CGPoint) -> Void
    let onDoubleTouch: (CGPoint, CGPoint) -> Void
    let onTouchEnded: () -> Void

    func makeUIView(context: Context) -> TouchTrackingView {
        let view = TouchTrackingView()
        view.backgroundColor = .clear
        view.onSingleTouch = onSingleTouch
        view.onDoubleTouch = onDoubleTouch
        view.onTouchEnded = onTouchEnded
        return view
    }

    func updateUIView(_ uiView: TouchTrackingView, context: Context) {
        uiView.onSingleTouch = onSingleTouch
        uiView.onDoubleTouch = onDoubleTouch
        uiView.onTouchEnded = onTouchEnded
    }
}

class TouchTrackingView: UIView, UIGestureRecognizerDelegate {
    var onSingleTouch: ((CGPoint) -> Void)?
    var onDoubleTouch: ((CGPoint, CGPoint) -> Void)?
    var onTouchEnded: (() -> Void)?

    private var panGesture: UIPanGestureRecognizer!

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true

        // 使用 UIPanGestureRecognizer 来阻止导航返回手势
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        panGesture.maximumNumberOfTouches = 2
        panGesture.minimumNumberOfTouches = 1
        addGestureRecognizer(panGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let touchCount = gesture.numberOfTouches

        switch gesture.state {
        case .began, .changed:
            if touchCount == 1 {
                let location = gesture.location(in: self)
                onSingleTouch?(location)
            } else if touchCount >= 2 {
                let loc1 = gesture.location(ofTouch: 0, in: self)
                let loc2 = gesture.location(ofTouch: 1, in: self)
                onDoubleTouch?(loc1, loc2)
            }
        case .ended, .cancelled, .failed:
            onTouchEnded?()
        default:
            break
        }
    }

    // 允许同时识别多个手势
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 阻止与导航返回手势同时识别
        if let panGesture = otherGestureRecognizer as? UIPanGestureRecognizer {
            // 检查是否是导航控制器的返回手势
            if panGesture.view is UINavigationController ||
               String(describing: type(of: panGesture)).contains("ScreenEdge") ||
               panGesture.name == "_UINavigationInteractiveTransition" {
                return false
            }
        }
        return true
    }

    // 我们的手势优先于其他手势
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 让其他边缘手势等待我们的手势失败
        if otherGestureRecognizer is UIScreenEdgePanGestureRecognizer {
            return true
        }
        return false
    }

}

// MARK: - 简化版本

extension InteractiveStockChart {
    static func simple(data: [PriceCacheData], currency: String = "USD", timeRange: TimeRange = .threeMonths) -> InteractiveStockChart {
        InteractiveStockChart(data: data, currency: currency, timeRange: timeRange, isInteracting: .constant(false))
    }
}

#Preview {
    VStack {
        InteractiveStockChart(
            data: [],
            currency: "USD",
            timeRange: .day
        )
        .frame(height: 250)
        .padding()
        .background(AppColors.cardSurface)
    }
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
