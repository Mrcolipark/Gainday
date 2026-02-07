import SwiftUI
import SwiftData

/// 日详情弹窗 - 增强版
struct DayDetailSheet: View {
    let date: Date
    let snapshot: DailySnapshot?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]

    @State private var animateContent = false
    @State private var previousSnapshot: DailySnapshot?
    @State private var weekSnapshots: [DailySnapshot] = []

    @AppStorage("baseCurrency") private var baseCurrency = "JPY"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let snapshot = snapshot {
                        // 日盈亏主卡片
                        mainPnLCard(snapshot)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 15)

                        // 与前一日对比
                        if let prev = previousSnapshot {
                            comparisonCard(current: snapshot, previous: prev)
                                .opacity(animateContent ? 1 : 0)
                                .offset(y: animateContent ? 0 : 12)
                        }

                        // 近期趋势
                        if !weekSnapshots.isEmpty {
                            trendCard
                                .opacity(animateContent ? 1 : 0)
                                .offset(y: animateContent ? 0 : 10)
                        }

                        // 波动最大的持仓
                        let topMovers = snapshot.topMovers(limit: 5)
                        if !topMovers.isEmpty {
                            topMoversCard(topMovers)
                                .opacity(animateContent ? 1 : 0)
                                .offset(y: animateContent ? 0 : 8)
                        }

                        // 账户明细
                        portfolioBreakdownCard
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 6)

                    } else {
                        emptyState
                    }
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(AppColors.background)
            .navigationTitle(date.fullDateString)
            #if os(iOS)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .task {
                await loadContextData()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    animateContent = true
                }
            }
        }
    }

    // MARK: - 数据加载

    private func loadContextData() async {
        do {
            // 加载前一日快照
            let prevDate = date.adding(days: -1)
            let prevSnapshots = try SnapshotService.shared.fetchSnapshots(
                from: prevDate.adding(days: -5),
                to: prevDate,
                portfolioID: nil,
                modelContext: modelContext
            )
            previousSnapshot = prevSnapshots.last

            // 加载最近7天趋势
            let weekStart = date.adding(days: -6)
            weekSnapshots = try SnapshotService.shared.fetchSnapshots(
                from: weekStart,
                to: date,
                portfolioID: nil,
                modelContext: modelContext
            )
        } catch {
            print("Failed to load context data: \(error)")
        }
    }

    // MARK: - 主盈亏卡片

    private func mainPnLCard(_ snapshot: DailySnapshot) -> some View {
        VStack(spacing: 16) {
            // 头部标签
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill((snapshot.dailyPnL >= 0 ? AppColors.profit : AppColors.loss).opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: snapshot.dailyPnL >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(snapshot.dailyPnL >= 0 ? AppColors.profit : AppColors.loss)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("当日盈亏".localized)
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)

                        Text(date.weekdayString)
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                Spacer()

                // 百分比标签
                HStack(spacing: 4) {
                    Image(systemName: snapshot.dailyPnL >= 0 ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                    Text(snapshot.dailyPnLPercent.percentFormatted())
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(snapshot.dailyPnL >= 0 ? AppColors.profit : AppColors.loss)
                )
            }

            // 主金额
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(snapshot.dailyPnL >= 0 ? "+" : "")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(snapshot.dailyPnL >= 0 ? AppColors.profit : AppColors.loss)

                Text(abs(snapshot.dailyPnL).currencyFormatted(code: baseCurrency))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(snapshot.dailyPnL >= 0 ? AppColors.profit : AppColors.loss)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(AppColors.dividerColor)

            // 详细数据 - 2x2 网格
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                DetailStatCell(
                    icon: "chart.bar.fill",
                    iconColor: .blue,
                    title: "持仓价值".localized,
                    value: snapshot.totalValue.compactFormatted(),
                    subValue: baseCurrency
                )

                DetailStatCell(
                    icon: "banknote.fill",
                    iconColor: .orange,
                    title: "持仓成本".localized,
                    value: snapshot.totalCost.compactFormatted(),
                    subValue: baseCurrency
                )

                DetailStatCell(
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    iconColor: snapshot.cumulativePnL >= 0 ? AppColors.profit : AppColors.loss,
                    title: "累计盈亏".localized,
                    value: snapshot.cumulativePnL.compactFormatted(showSign: true),
                    subValue: snapshot.unrealizedPnLPercent.percentFormatted()
                )

                DetailStatCell(
                    icon: "percent",
                    iconColor: .purple,
                    title: "收益率".localized,
                    value: snapshot.unrealizedPnLPercent.percentFormatted(),
                    subValue: "累计".localized
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - 与前一日对比卡片

    private func comparisonCard(current: DailySnapshot, previous: DailySnapshot) -> some View {
        let valueDiff = current.totalValue - previous.totalValue
        let pnlDiff = current.dailyPnL - previous.dailyPnL

        return VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.cyan)
                }

                Text("与前一日对比".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }

            HStack(spacing: 16) {
                // 价值变化
                ComparisonItem(
                    title: "价值变化".localized,
                    value: valueDiff.compactFormatted(showSign: true),
                    isPositive: valueDiff >= 0
                )

                Divider()
                    .frame(height: 40)

                // 盈亏变化
                ComparisonItem(
                    title: "盈亏变化".localized,
                    value: pnlDiff.compactFormatted(showSign: true),
                    isPositive: pnlDiff >= 0
                )
            }
            .padding(.vertical, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - 近期趋势卡片

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.indigo)
                }

                Text("近7日趋势".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                // 连续盈利/亏损天数
                let streak = calculateStreak()
                if streak != 0 {
                    Text(streak > 0 ? "\("连盈".localized)\(streak)\("天".localized)" : "\("连亏".localized)\(abs(streak))\("天".localized)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(streak > 0 ? AppColors.profit : AppColors.loss)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill((streak > 0 ? AppColors.profit : AppColors.loss).opacity(0.15))
                        )
                }
            }

            // 趋势条形图
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(weekSnapshots, id: \.id) { snap in
                    VStack(spacing: 4) {
                        // 条形
                        let maxPnL = weekSnapshots.map { abs($0.dailyPnL) }.max() ?? 1
                        let normalizedHeight = min(abs(snap.dailyPnL) / maxPnL, 1.0)
                        let barHeight = max(normalizedHeight * 60, 8)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(snap.dailyPnL >= 0 ? AppColors.profit : AppColors.loss)
                            .frame(height: barHeight)

                        // 日期
                        Text(snap.date.dayString)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(
                                snap.date.startOfDay == date.startOfDay
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)

            // 汇总
            HStack {
                let totalWeekPnL = weekSnapshots.reduce(0) { $0 + $1.dailyPnL }
                let profitDays = weekSnapshots.filter { $0.dailyPnL > 0 }.count
                let lossDays = weekSnapshots.filter { $0.dailyPnL < 0 }.count

                Text("\("周盈亏".localized): \(totalWeekPnL.compactFormatted(showSign: true))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(totalWeekPnL >= 0 ? AppColors.profit : AppColors.loss)

                Spacer()

                Text("\("盈".localized)\(profitDays) / \("亏".localized)\(lossDays)")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private func calculateStreak() -> Int {
        guard !weekSnapshots.isEmpty else { return 0 }

        let sorted = weekSnapshots.sorted { $0.date > $1.date }
        var streak = 0
        let firstPnL = sorted.first?.dailyPnL ?? 0

        if firstPnL >= 0 {
            for snap in sorted {
                if snap.dailyPnL >= 0 {
                    streak += 1
                } else {
                    break
                }
            }
        } else {
            for snap in sorted {
                if snap.dailyPnL < 0 {
                    streak -= 1
                } else {
                    break
                }
            }
        }

        return streak
    }

    // MARK: - 波动最大持仓卡片

    private func topMoversCard(_ movers: [HoldingDailyPnL]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                Text("当日波动最大".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text("Top \(movers.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
            }

            // 持仓列表
            VStack(spacing: 0) {
                ForEach(Array(movers.enumerated()), id: \.element.symbol) { index, mover in
                    HStack(spacing: 12) {
                        // 排名
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(index < 3 ? Color.orange : AppColors.textTertiary)
                            .frame(width: 20)

                        // 股票信息
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mover.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary)

                            Text(mover.name)
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textTertiary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // 盈亏
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(mover.dailyPnL.compactFormatted(showSign: true))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(mover.dailyPnL >= 0 ? AppColors.profit : AppColors.loss)

                            Text(mover.dailyPnLPercent.percentFormatted())
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(mover.dailyPnL >= 0 ? AppColors.profit.opacity(0.8) : AppColors.loss.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 10)

                    if index < movers.count - 1 {
                        Divider()
                            .background(AppColors.dividerColor)
                            .padding(.leading, 32)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - 账户明细卡片

    private var portfolioBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.teal)
                }

                Text("账户明细".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }

            // 账户列表
            VStack(spacing: 0) {
                ForEach(Array(portfolios.enumerated()), id: \.element.id) { index, portfolio in
                    // 查找该账户当日的快照
                    if let portfolioSnap = fetchPortfolioSnapshot(for: portfolio) {
                        HStack(spacing: 12) {
                            // 颜色标记
                            Circle()
                                .fill(portfolio.tagColor)
                                .frame(width: 10, height: 10)

                            // 账户名
                            Text(portfolio.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppColors.textPrimary)

                            Spacer()

                            // 盈亏
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(portfolioSnap.dailyPnL.compactFormatted(showSign: true))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(portfolioSnap.dailyPnL >= 0 ? AppColors.profit : AppColors.loss)

                                Text(portfolioSnap.dailyPnLPercent.percentFormatted())
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                        }
                        .padding(.vertical, 12)

                        if index < portfolios.count - 1 {
                            Divider()
                                .background(AppColors.dividerColor)
                                .padding(.leading, 22)
                        }
                    }
                }
            }

            if portfolios.isEmpty {
                Text("暂无账户数据".localized)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private func fetchPortfolioSnapshot(for portfolio: Portfolio) -> DailySnapshot? {
        do {
            let dayStart = date.startOfDay
            let dayEnd = date.adding(days: 1).startOfDay
            let allSnapshots = try modelContext.fetch(FetchDescriptor<DailySnapshot>())
            return allSnapshots.first { snap in
                snap.date >= dayStart && snap.date < dayEnd && snap.portfolioID == portfolio.id.uuidString
            }
        } catch {
            return nil
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppColors.textTertiary.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 32))
                    .foregroundStyle(AppColors.textTertiary)
            }

            VStack(spacing: 8) {
                Text("该日无数据".localized)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)

                Text("持仓数据在交易日收盘后自动生成".localized)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            // 日期信息
            VStack(spacing: 4) {
                Text(date.fullDateString)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)

                Text(date.weekdayString)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardSurface)
        )
        .padding(.top, 20)
    }
}

// MARK: - 详情统计单元格

private struct DetailStatCell: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subValue: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textTertiary)

                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(subValue)
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.background)
        )
    }
}

// MARK: - 对比项

private struct ComparisonItem: View {
    let title: String
    let value: String
    let isPositive: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textTertiary)

            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 11, weight: .semibold))

                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isPositive ? AppColors.profit : AppColors.loss)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DayDetailSheet(date: Date(), snapshot: nil)
        .modelContainer(for: [DailySnapshot.self, Portfolio.self], inMemory: true)
        .preferredColorScheme(.dark)
}
