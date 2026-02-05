import SwiftUI
import SwiftData
import Charts

/// 极简风格的主页
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]
    @Query(sort: \DailySnapshot.date) private var allSnapshots: [DailySnapshot]

    @State private var viewModel = HomeViewModel()
    @State private var animateCards = false
    @State private var showAddTransaction = false
    @AppStorage("baseCurrency") private var baseCurrency = "JPY"

    var body: some View {
        @Bindable var vm = viewModel
        AppNavigationWrapper(title: "GainDay") {
            ScrollView {
                LazyVStack(spacing: 16) {
                    PortfolioHeaderView(
                        totalValue: viewModel.totalValue,
                        dailyPnL: viewModel.dailyPnL,
                        dailyPnLPercent: viewModel.dailyPnLPercent,
                        unrealizedPnL: viewModel.unrealizedPnL,
                        unrealizedPnLPercent: viewModel.unrealizedPnLPercent,
                        baseCurrency: baseCurrency
                    )
                    .padding(.horizontal)

                    // 视图模式控制栏
                    HStack(spacing: 12) {
                        ViewModeSelector(selectedMode: $vm.displayMode)

                        Spacer()

                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(AppColors.textSecondary)
                        } else if let lastTime = viewModel.lastRefreshTimeFormatted {
                            Text(lastTime)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(AppColors.textTertiary)
                        }

                        ChangeToggleButton(showPercent: $vm.showPercentChange)
                    }
                    .padding(.horizontal)
                    .opacity(animateCards ? 1 : 0)

                    // 账户区块列表
                    portfolioSections
                        .opacity(animateCards ? 1 : 0)

                    // 空状态
                    if portfolios.isEmpty {
                        emptyStateCard
                    }

                    // 迷你分析图表
                    if !allSnapshots.isEmpty {
                        miniAnalyticsSection
                            .opacity(animateCards ? 1 : 0)
                    }
                }
                .padding(.bottom, 30)
            }
            .background(AppColors.background)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    addButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    refreshButton
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView(portfolios: portfolios)
            }
            .refreshable {
                await viewModel.refreshAll(portfolios: portfolios, baseCurrency: baseCurrency, modelContext: modelContext)
            }
            .task {
                await viewModel.refreshAll(portfolios: portfolios, baseCurrency: baseCurrency, modelContext: modelContext)
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animateCards = true
                }
            }
            .onChange(of: portfolios.count) { _, newCount in
                if newCount > 0 {
                    Task {
                        await viewModel.refreshAll(portfolios: portfolios, baseCurrency: baseCurrency, modelContext: modelContext)
                    }
                }
            }
        }
    }

    // MARK: - 账户区块

    @ViewBuilder
    private var portfolioSections: some View {
        if !viewModel.portfolioPnLs.isEmpty {
            ForEach(viewModel.portfolioPnLs, id: \.portfolio.id) { portfolioPnL in
                PortfolioSectionView(
                    portfolioPnL: portfolioPnL,
                    quotes: viewModel.quotes,
                    displayMode: viewModel.displayMode,
                    showPercent: viewModel.showPercentChange,
                    isExpanded: viewModel.isPortfolioExpanded(portfolioPnL.portfolio.id.uuidString),
                    onToggle: {
                        viewModel.togglePortfolioExpansion(portfolioPnL.portfolio.id.uuidString)
                    }
                )
                .id("\(portfolioPnL.portfolio.id)-\(viewModel.displayMode.rawValue)")
                .padding(.horizontal)
            }
        } else if !portfolios.isEmpty {
            ForEach(portfolios) { portfolio in
                fallbackPortfolioSection(portfolio)
                    .id("\(portfolio.id)-\(viewModel.displayMode.rawValue)-fallback")
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - 后备账户区块

    @ViewBuilder
    private func fallbackPortfolioSection(_ portfolio: Portfolio) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(portfolio.tagColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(portfolio.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(portfolio.holdings.count) 持仓")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)

            Rectangle()
                .fill(AppColors.dividerColor)
                .frame(height: 1)
                .padding(.horizontal, 16)

            fallbackHoldingsContent(portfolio: portfolio)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - 后备持仓内容

    @ViewBuilder
    private func fallbackHoldingsContent(portfolio: Portfolio) -> some View {
        switch viewModel.displayMode {
        case .basic:
            VStack(spacing: 0) {
                ForEach(portfolio.holdings) { holding in
                    HoldingRow(
                        holding: holding,
                        quote: viewModel.quotes[holding.symbol],
                        displayMode: .basic,
                        showPercent: viewModel.showPercentChange
                    )

                    if holding.id != portfolio.holdings.last?.id {
                        Rectangle()
                            .fill(AppColors.dividerColor)
                            .frame(height: 1)
                            .padding(.leading, 16)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

        case .details:
            HoldingDetailsTable(
                holdings: portfolio.holdings,
                quotes: viewModel.quotes,
                showPercent: viewModel.showPercentChange,
                onHoldingTap: { _ in }
            )
            .frame(minHeight: CGFloat(portfolio.holdings.count) * 56 + 48)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

        case .holdings:
            VStack(spacing: 8) {
                ForEach(portfolio.holdings) { holding in
                    ExpandableHoldingRow(
                        holding: holding,
                        quote: viewModel.quotes[holding.symbol],
                        showPercent: viewModel.showPercentChange
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }

    // MARK: - 空状态

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 44))
                .foregroundStyle(AppColors.textTertiary)

            VStack(spacing: 8) {
                Text("开始您的投资之旅")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("在设置中添加您的第一个账户")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
        .padding(.horizontal)
    }

    // MARK: - 迷你分析图表

    private var miniAnalyticsSection: some View {
        VStack(spacing: 12) {
            // 月度盈亏
            VStack(alignment: .leading, spacing: 10) {
                Text("月度盈亏")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                MonthlyBarChart(snapshots: allSnapshots)
                    .frame(height: 120)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
            .padding(.horizontal)

            // 累计盈亏
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("累计盈亏")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    if let last = allSnapshots.last {
                        Text(last.cumulativePnL.currencyFormatted(code: baseCurrency, showSign: true))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(last.cumulativePnL >= 0 ? AppColors.profit : AppColors.loss)
                    }
                }

                CumulativeChart(snapshots: Array(allSnapshots.suffix(90)))
                    .frame(height: 100)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
            .padding(.horizontal)
        }
    }

    // MARK: - 工具栏按钮

    private var addButton: some View {
        Button {
            showAddTransaction = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    private var refreshButton: some View {
        Button {
            Task {
                await viewModel.refreshAll(portfolios: portfolios, baseCurrency: baseCurrency, modelContext: modelContext)
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
                .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
        }
        .disabled(viewModel.isLoading)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Portfolio.self, DailySnapshot.self], inMemory: true)
        .preferredColorScheme(.dark)
}
