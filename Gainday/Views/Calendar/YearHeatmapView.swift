import SwiftUI

/// 年度热力图 - 统一设计语言
struct YearHeatmapView: View {
    let year: Int
    let snapshots: [Date: DailySnapshot]

    @State private var tappedDate: Date?
    @State private var showTooltip = false
    @State private var animateGrid = false

    private let cellSize: CGFloat = 18
    private let cellSpacing: CGFloat = 3
    private let rows = Array(repeating: GridItem(.fixed(18), spacing: 3), count: 7)
    private let weekdayLabels = ["日", "一", "二", "三", "四", "五", "六"]
    private let monthLabels = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]

    private var yearSnapshots: [DailySnapshot] {
        snapshots.values.filter { $0.date.year == year }
    }

    private var totalPnL: Double {
        yearSnapshots.reduce(0) { $0 + $1.dailyPnL }
    }

    var body: some View {
        VStack(spacing: 20) {
            // 年度标题卡片
            yearHeaderCard

            // 热力图卡片
            heatmapCard

            // 年度统计卡片
            yearStatsCard
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateGrid = true
            }
        }
    }

    // MARK: - 年度标题卡片

    private var yearHeaderCard: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.profit.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.profit)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(year))年度")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("投资热力图")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            if !yearSnapshots.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("年度收益")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textTertiary)

                    Text(totalPnL.compactFormatted(showSign: true))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(totalPnL >= 0 ? AppColors.profit : AppColors.loss)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((totalPnL >= 0 ? AppColors.profit : AppColors.loss).opacity(0.15))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - 热力图卡片

    private var heatmapCard: some View {
        VStack(spacing: 12) {
            // 月份标签 + 热力图网格（同步滚动）
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    // 热力图网格（包含月份标签）
                    HStack(alignment: .top, spacing: 0) {
                        // 星期标签（固定在左侧）
                        VStack(spacing: 0) {
                            // 月份标签行的占位
                            Color.clear.frame(height: 16)

                            VStack(spacing: cellSpacing) {
                                ForEach(weekdayLabels, id: \.self) { label in
                                    Text(label)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(AppColors.textTertiary)
                                        .frame(width: 20, height: cellSize)
                                }
                            }
                        }
                        .padding(.trailing, 4)

                        // 按月份排列的热力图
                        HStack(alignment: .top, spacing: 4) {
                            ForEach(1...12, id: \.self) { month in
                                monthGridView(month: month)
                            }
                        }
                    }
                }
            }
            .frame(height: 7 * (cellSize + cellSpacing) - cellSpacing + 20)

            // 提示信息
            if showTooltip, let date = tappedDate, let snap = snapshots[date.startOfDay] {
                tooltipView(date: date, snapshot: snap)
            }

            // 颜色图例
            colorLegend
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    /// 单月热力图（包含月份标签）
    private func monthGridView(month: Int) -> some View {
        let calendar = Calendar.current
        let days = daysInMonth(month)
        let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1 // 0-indexed (Sun=0)
        let weeksCount = (firstWeekday + days.count + 6) / 7

        return VStack(alignment: .leading, spacing: 4) {
            // 月份标签
            Text(monthLabels[month - 1])
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
                .frame(height: 12)

            // 周列排列（每列是一周）
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(0..<weeksCount, id: \.self) { weekIndex in
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { dayOfWeek in
                            let dayIndex = weekIndex * 7 + dayOfWeek - firstWeekday
                            if dayIndex >= 0 && dayIndex < days.count {
                                let date = days[dayIndex]
                                let snapshot = snapshots[date.startOfDay]
                                let pct = snapshot?.dailyPnLPercent ?? 0
                                let hasData = snapshot != nil
                                let globalIndex = (month - 1) * 31 + dayIndex

                                heatmapCell(date: date, pct: pct, hasData: hasData, index: globalIndex)
                            } else {
                                Color.clear.frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
        }
    }

    /// 获取指定月份的所有日期
    private func daysInMonth(_ month: Int) -> [Date] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }

        return range.compactMap { day in
            calendar.date(from: DateComponents(year: year, month: month, day: day))
        }
    }

    private func heatmapCell(date: Date, pct: Double, hasData: Bool, index: Int) -> some View {
        let isSelected = tappedDate == date && showTooltip
        let isFuture = date > Date()

        return ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(hasData ? AppColors.pnlColor(percent: pct) : Color.white.opacity(isFuture ? 0.03 : 0.08))

            if hasData {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }

            if isSelected {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(.white, lineWidth: 2)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .shadow(color: hasData ? (pct >= 0 ? AppColors.profit : AppColors.loss).opacity(0.25) : .clear, radius: 2, x: 0, y: 1)
        .scaleEffect(animateGrid ? 1 : 0.5)
        .opacity(animateGrid ? 1 : 0)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.001),
            value: animateGrid
        )
        .onTapGesture {
            if hasData {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if tappedDate == date {
                        showTooltip = false
                        tappedDate = nil
                    } else {
                        tappedDate = date
                        showTooltip = true
                    }
                }
            }
        }
    }

    private func tooltipView(date: Date, snapshot: DailySnapshot) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.fullDateString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(date.weekdayString)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(snapshot.dailyPnL.compactFormatted(showSign: true))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(snapshot.dailyPnL >= 0 ? AppColors.profit : AppColors.loss)

                Text(snapshot.dailyPnLPercent.percentFormatted())
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(snapshot.dailyPnL >= 0 ? AppColors.profit : AppColors.loss)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.elevatedSurface)
        )
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .scale(scale: 0.95))
        ))
    }

    private var colorLegend: some View {
        HStack(spacing: 10) {
            Text("亏损")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.loss)

            HStack(spacing: 3) {
                ForEach([-5.0, -2.0, -0.5, 0, 0.5, 2.0, 5.0], id: \.self) { pct in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(AppColors.pnlColor(percent: pct))
                        .frame(width: 20, height: 18)
                        .overlay {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.15), .clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                }
            }

            Text("盈利")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.profit)
        }
        .padding(.top, 4)
    }

    // MARK: - 年度统计卡片

    private var yearStatsCard: some View {
        let profitDays = yearSnapshots.filter { $0.dailyPnL > 0 }.count
        let lossDays = yearSnapshots.filter { $0.dailyPnL < 0 }.count
        let totalDays = profitDays + lossDays
        let winRate = totalDays > 0 ? Double(profitDays) / Double(totalDays) * 100 : 0
        let maxProfit = yearSnapshots.map(\.dailyPnL).max() ?? 0
        let maxLoss = yearSnapshots.map(\.dailyPnL).min() ?? 0

        return VStack(spacing: 16) {
            // 标题
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                    Text("年度统计")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }

                Spacer()
            }

            // 统计网格
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    icon: "arrow.up.circle.fill",
                    iconColor: AppColors.profit,
                    title: "盈利天数",
                    value: "\(profitDays)",
                    valueColor: AppColors.profit
                )

                StatCard(
                    icon: "arrow.down.circle.fill",
                    iconColor: AppColors.loss,
                    title: "亏损天数",
                    value: "\(lossDays)",
                    valueColor: AppColors.loss
                )

                StatCard(
                    icon: "target",
                    iconColor: winRate >= 50 ? AppColors.profit : AppColors.loss,
                    title: "胜率",
                    value: String(format: "%.1f%%", winRate),
                    valueColor: winRate >= 50 ? AppColors.profit : AppColors.loss
                )

                StatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .blue,
                    title: "交易天数",
                    value: "\(totalDays)",
                    valueColor: AppColors.textPrimary
                )

                StatCard(
                    icon: "arrow.up.right.circle.fill",
                    iconColor: AppColors.profit,
                    title: "最大盈利",
                    value: maxProfit.compactFormatted(showSign: true),
                    valueColor: AppColors.profit
                )

                StatCard(
                    icon: "arrow.down.right.circle.fill",
                    iconColor: AppColors.loss,
                    title: "最大亏损",
                    value: maxLoss.compactFormatted(showSign: true),
                    valueColor: AppColors.loss
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }
}

// MARK: - 统计卡片

private struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textTertiary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.elevatedSurface)
        )
    }
}

// MARK: - Date Extensions

extension Date {
    var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }

    var weekdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }
}

#Preview {
    ScrollView {
        YearHeatmapView(year: 2026, snapshots: [:])
            .padding(16)
    }
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
