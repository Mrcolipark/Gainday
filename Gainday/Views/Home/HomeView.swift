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
    @State private var portfolioForAddTransaction: Portfolio?
    @State private var showNISAOverview = false
    @State private var showAddAccount = false
    @AppStorage("baseCurrency") private var baseCurrency = "JPY"

    /// 是否有 NISA 账户
    private var hasNISAAccounts: Bool {
        portfolios.contains { AccountType(rawValue: $0.accountType)?.isNISA == true }
    }

    /// 计算 NISA 额度
    private var nisaQuota: NISAOverallQuota {
        NISAQuotaCalculator.calculateOverall(holdings: portfolios.flatMap(\.holdings))
    }

    var body: some View {
        @Bindable var vm = viewModel
        AppNavigationWrapper(title: "GainDay") {
            ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 16) {
                    // 品牌标题
                    HStack {
                        Text("GainDay")
                            .font(.custom("Georgia-Bold", size: 28))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.profit, AppColors.profit.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("盈历".localized)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    // 投资组合头部
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

                    // NISA 概览卡片（仅 NISA 用户可见）
                    if hasNISAAccounts {
                        nisaQuickCard
                            .opacity(animateCards ? 1 : 0)
                    }

                    // 账户区块列表
                    portfolioSections(scrollProxy: scrollProxy)
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
            } // ScrollViewReader
            .refreshable {
                await viewModel.refreshAll(portfolios: portfolios, baseCurrency: baseCurrency, modelContext: modelContext)
            }
            .background(AppColors.background)
            .sheet(item: $portfolioForAddTransaction, onDismiss: {
                Task {
                    await viewModel.refreshAll(portfolios: portfolios, baseCurrency: baseCurrency, modelContext: modelContext)
                }
            }) { preselected in
                AddTransactionView(portfolios: [preselected] + portfolios.filter { $0.id != preselected.id })
            }
            .sheet(isPresented: $showNISAOverview) {
                NISAOverviewView()
            }
            .sheet(isPresented: $showAddAccount) {
                AddAccountSheet()
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
            .onChange(of: baseCurrency) { _, _ in
                Task {
                    await viewModel.refreshAll(portfolios: portfolios, baseCurrency: baseCurrency, modelContext: modelContext)
                }
            }
        }
    }

    // MARK: - 账户区块

    @ViewBuilder
    private func portfolioSections(scrollProxy: ScrollViewProxy) -> some View {
        ForEach(viewModel.portfolioPnLs, id: \.portfolio.id) { portfolioPnL in
            PortfolioSectionView(
                portfolioPnL: portfolioPnL,
                quotes: viewModel.quotes,
                displayMode: viewModel.displayMode,
                showPercent: viewModel.showPercentChange,
                isExpanded: viewModel.isPortfolioExpanded(portfolioPnL.portfolio.id.uuidString),
                scrollProxy: scrollProxy,
                onToggle: {
                    viewModel.togglePortfolioExpansion(portfolioPnL.portfolio.id.uuidString)
                },
                onRefresh: {
                    Task {
                        await viewModel.refreshAll(portfolios: portfolios, baseCurrency: baseCurrency, modelContext: modelContext)
                    }
                }
            )
            .id("\(portfolioPnL.portfolio.id)-\(viewModel.displayMode.rawValue)")
            .padding(.horizontal)
        }
    }

    // MARK: - NISA 概览卡片

    private var nisaQuickCard: some View {
        Button {
            showNISAOverview = true
        } label: {
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AccountType.nisa_tsumitate.color)

                        Text("NISA 非課税枠".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("详情".localized)
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                // 年度额度进度
                HStack(spacing: 16) {
                    // つみたて枠
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AccountType.nisa_tsumitate.color)
                                .frame(width: 6, height: 6)

                            Text("つみたて")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        NISACompactProgressBar(
                            used: nisaQuota.tsumitateAnnualUsed,
                            limit: nisaQuota.tsumitateAnnualLimit,
                            color: AccountType.nisa_tsumitate.color
                        )
                    }

                    // 成長枠
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AccountType.nisa_growth.color)
                                .frame(width: 6, height: 6)

                            Text("成長")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        NISACompactProgressBar(
                            used: nisaQuota.growthAnnualUsed,
                            limit: nisaQuota.growthAnnualLimit,
                            color: AccountType.nisa_growth.color
                        )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - 空状态

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 44))
                .foregroundStyle(AppColors.textTertiary)

            VStack(spacing: 8) {
                Text("开始您的投资之旅".localized)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("在设置中添加您的第一个账户".localized)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Button {
                showAddAccount = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("创建账户".localized)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.profit)
                )
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
                Text("月度盈亏".localized)
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
                    Text("累计盈亏".localized)
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

}

#Preview {
    HomeView()
        .modelContainer(for: [Portfolio.self, DailySnapshot.self], inMemory: true)
        .preferredColorScheme(.dark)
}
