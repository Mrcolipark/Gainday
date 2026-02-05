import SwiftUI

struct YearHeatmapView: View {
    let year: Int
    let snapshots: [Date: DailySnapshot]

    @Environment(\.colorScheme) private var colorScheme
    @State private var tappedDate: Date?
    @State private var showTooltip = false
    @State private var animateGrid = false

    // Larger cells for better visibility
    private let cellSize: CGFloat = 18
    private let cellSpacing: CGFloat = 3
    private let rows = Array(repeating: GridItem(.fixed(18), spacing: 3), count: 7)
    private let weekdayLabels = ["日", "一", "二", "三", "四", "五", "六"]
    private let monthLabels = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]

    private var yearDays: [Date] {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!

        var days: [Date] = []
        var current = startOfYear
        while current <= endOfYear {
            days.append(current)
            current = current.adding(days: 1)
        }
        return days
    }

    // Group days by week for month labels
    private var weekStartDates: [Date] {
        var weeks: [Date] = []
        let calendar = Calendar.current
        var current = yearDays.first ?? Date()

        // Align to start of week
        while calendar.component(.weekday, from: current) != 1 {
            current = current.adding(days: -1)
        }

        let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!
        while current <= endOfYear {
            weeks.append(current)
            current = current.adding(days: 7)
        }
        return weeks
    }

    var body: some View {
        VStack(spacing: 16) {
            // Year header with stats
            yearHeader

            // Month labels row
            monthLabelsRow

            // Main heatmap grid
            heatmapGrid

            // Tooltip when tapped
            if showTooltip, let date = tappedDate, let snap = snapshots[date.startOfDay] {
                tooltipView(date: date, snapshot: snap)
            }

            // Color legend
            colorLegend

            // Divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .secondary.opacity(0.15), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            // Year statistics
            yearStatsGrid
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.teal.opacity(0.08), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateGrid = true
            }
        }
    }

    // MARK: - Year Header

    private var yearHeader: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.teal.opacity(0.2), .teal.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.teal)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(year))年度")
                        .font(.system(.title3, design: .default, weight: .bold))
                    Text("投资热力图")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Year total P&L badge
            let yearSnapshots = snapshots.values.filter { $0.date.year == year }
            let totalPnL = yearSnapshots.reduce(0) { $0 + $1.dailyPnL }
            if !yearSnapshots.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("年度收益")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(totalPnL.compactFormatted(showSign: true))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(totalPnL >= 0 ? AppColors.profit : AppColors.loss)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((totalPnL >= 0 ? Color.green : Color.red).opacity(0.1))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder((totalPnL >= 0 ? Color.green : Color.red).opacity(0.2), lineWidth: 0.5)
                        }
                }
            }
        }
    }

    // MARK: - Month Labels Row

    private var monthLabelsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Spacer for weekday labels column
                Color.clear
                    .frame(width: 24)

                // Month labels positioned at approximate week positions
                HStack(spacing: 0) {
                    ForEach(0..<12, id: \.self) { monthIndex in
                        Text(monthLabels[monthIndex])
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: weeksInMonth(monthIndex + 1) * (cellSize + cellSpacing), alignment: .leading)
                    }
                }
            }
        }
    }

    private func weeksInMonth(_ month: Int) -> CGFloat {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return 4
        }
        let daysInMonth = range.count
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        return CGFloat((daysInMonth + firstWeekday - 1 + 6) / 7)
    }

    // MARK: - Heatmap Grid

    private var heatmapGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                // Weekday labels column
                VStack(spacing: cellSpacing) {
                    ForEach(weekdayLabels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: cellSize)
                    }
                }
                .padding(.trailing, 4)

                // Main grid
                LazyHGrid(rows: rows, spacing: cellSpacing) {
                    // Pad to start from correct weekday
                    let firstDay = yearDays.first ?? Date()
                    let offset = firstDay.weekday - 1
                    ForEach(0..<offset, id: \.self) { _ in
                        Color.clear
                            .frame(width: cellSize, height: cellSize)
                    }

                    ForEach(Array(yearDays.enumerated()), id: \.element) { index, date in
                        let snapshot = snapshots[date.startOfDay]
                        let pct = snapshot?.dailyPnLPercent ?? 0
                        let hasData = snapshot != nil

                        heatmapCell(date: date, pct: pct, hasData: hasData, index: index)
                    }
                }
            }
        }
        .frame(height: 7 * (cellSize + cellSpacing) - cellSpacing)
    }

    private func heatmapCell(date: Date, pct: Double, hasData: Bool, index: Int) -> some View {
        let isSelected = tappedDate == date && showTooltip

        return ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(hasData ? AppColors.pnlColor(percent: pct) : Color(uiColor: .tertiarySystemFill))

            // Glass highlight for data cells
            if hasData {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }

            // Selection ring
            if isSelected {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(.white, lineWidth: 2)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .shadow(color: hasData ? (pct >= 0 ? Color.green : Color.red).opacity(0.3) : .clear, radius: 2, x: 0, y: 1)
        .scaleEffect(animateGrid ? 1 : 0.5)
        .opacity(animateGrid ? 1 : 0)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.7)
                .delay(Double(index) * 0.001),
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

    // MARK: - Tooltip

    private func tooltipView(date: Date, snapshot: DailySnapshot) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.fullDateString)
                    .font(.system(.subheadline, weight: .semibold))
                Text(date.weekdayString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(snapshot.dailyPnL.compactFormatted(showSign: true))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(snapshot.dailyPnL >= 0 ? AppColors.profit : AppColors.loss)
                Text(snapshot.dailyPnLPercent.percentFormatted())
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(snapshot.dailyPnL >= 0 ? AppColors.profit : AppColors.loss)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [(snapshot.dailyPnL >= 0 ? Color.green : Color.red).opacity(0.1), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .scale(scale: 0.95))
        ))
    }

    // MARK: - Color Legend

    private var colorLegend: some View {
        HStack(spacing: 8) {
            Text("亏损")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.red.opacity(0.9))

            HStack(spacing: 3) {
                ForEach([-5.0, -3.0, -1.5, -0.5, 0, 0.5, 1.5, 3.0, 5.0], id: \.self) { pct in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColors.pnlColor(percent: pct))
                        .frame(width: 20, height: 20)
                        .overlay {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.15), .clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                        }
                }
            }

            Text("盈利")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.green.opacity(0.9))
        }
    }

    // MARK: - Year Stats Grid

    private var yearStatsGrid: some View {
        let yearSnapshots = snapshots.values.filter { $0.date.year == year }
        let profitDays = yearSnapshots.filter { $0.dailyPnL > 0 }.count
        let lossDays = yearSnapshots.filter { $0.dailyPnL < 0 }.count
        let totalDays = profitDays + lossDays
        let winRate = totalDays > 0 ? Double(profitDays) / Double(totalDays) * 100 : 0
        let maxProfit = yearSnapshots.map(\.dailyPnL).max() ?? 0
        let maxLoss = yearSnapshots.map(\.dailyPnL).min() ?? 0

        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                icon: "arrow.up.circle.fill",
                iconColor: .green,
                title: "盈利天数",
                value: "\(profitDays)",
                valueColor: AppColors.profit
            )

            StatCard(
                icon: "arrow.down.circle.fill",
                iconColor: .red,
                title: "亏损天数",
                value: "\(lossDays)",
                valueColor: AppColors.loss
            )

            StatCard(
                icon: "target",
                iconColor: winRate >= 50 ? .green : .red,
                title: "胜率",
                value: String(format: "%.1f%%", winRate),
                valueColor: winRate >= 50 ? AppColors.profit : AppColors.loss
            )

            StatCard(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: .blue,
                title: "交易天数",
                value: "\(totalDays)",
                valueColor: .primary
            )

            StatCard(
                icon: "arrow.up.right.circle.fill",
                iconColor: .green,
                title: "最大单日盈利",
                value: maxProfit.compactFormatted(showSign: true),
                valueColor: AppColors.profit
            )

            StatCard(
                icon: "arrow.down.right.circle.fill",
                iconColor: .red,
                title: "最大单日亏损",
                value: maxLoss.compactFormatted(showSign: true),
                valueColor: AppColors.loss
            )
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
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

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Date Extensions for Year View

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
            .padding()
    }
    .background(AppColors.background)
}
