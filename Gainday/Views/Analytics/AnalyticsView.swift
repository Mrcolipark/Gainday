import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \DailySnapshot.date) private var allSnapshots: [DailySnapshot]
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]

    @State private var selectedRange: TimeRange = .month
    @State private var animateContent = false

    private var filteredSnapshots: [DailySnapshot] {
        guard let days = selectedRange.days else { return allSnapshots }
        let cutoff = Date().adding(days: -days)
        return allSnapshots.filter { $0.date >= cutoff }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Time range picker
                    Picker("时间范围", selection: $selectedRange) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Cumulative P&L Chart
                    cumulativeChartSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 15)

                    // Monthly Bar Chart
                    monthlyBarChartSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 10)

                    // Holdings Ranking
                    rankingSection
                        .opacity(animateContent ? 1 : 0)
                }
                .padding(.bottom, 20)
            }
            .background(analyticsBackground)
            .navigationTitle("分析")
            .task {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animateContent = true
                }
            }
        }
    }

    // MARK: - Background

    private var analyticsBackground: some View {
        AppColors.background
            .ignoresSafeArea()
    }

    // MARK: - Cumulative Chart

    private var cumulativeChartSection: some View {
        GlassCard(tint: .green) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("累计收益")
                        .font(.headline)
                    Spacer()
                    if let last = filteredSnapshots.last {
                        PnLText(last.cumulativePnL, style: .caption)
                    }
                }

                if filteredSnapshots.isEmpty {
                    emptyChartPlaceholder
                } else {
                    CumulativeChart(snapshots: filteredSnapshots)
                        .frame(height: 200)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Monthly Bar Chart

    private var monthlyBarChartSection: some View {
        GlassCard(tint: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("月度盈亏")
                        .font(.headline)
                }

                if allSnapshots.isEmpty {
                    emptyChartPlaceholder
                } else {
                    MonthlyBarChart(snapshots: allSnapshots)
                        .frame(height: 200)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Ranking

    private var rankingSection: some View {
        GlassCard(tint: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "list.number")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("持仓盈亏排行")
                        .font(.headline)
                }

                let allHoldings = portfolios.flatMap(\.holdings)
                if allHoldings.isEmpty {
                    emptyChartPlaceholder
                } else {
                    RankingChart(holdings: allHoldings)
                        .frame(height: max(CGFloat(allHoldings.count) * 32, 100))
                }
            }
        }
        .padding(.horizontal)
    }

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.secondary.opacity(0.08))
                    .frame(width: 48, height: 48)
                Image(systemName: "chart.xyaxis.line")
                    .font(.title2)
                    .foregroundStyle(.secondary.opacity(0.4))
            }
            Text("暂无数据")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }
}

#Preview {
    AnalyticsView()
        .modelContainer(for: [DailySnapshot.self, Portfolio.self], inMemory: true)
}
