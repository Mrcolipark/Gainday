import SwiftUI

/// iPhone 股票 App 风格的投资组合区块
struct PortfolioSectionView: View {
    let portfolioPnL: PnLCalculationService.PortfolioPnL
    let quotes: [String: MarketDataService.QuoteData]
    let displayMode: PortfolioDisplayMode
    let showPercent: Bool
    let isExpanded: Bool
    let onToggle: () -> Void

    @State private var animateIn = false
    @State private var selectedHolding: Holding?
    @State private var showHoldingDetail = false

    private var portfolio: Portfolio {
        portfolioPnL.portfolio
    }

    private var isPositive: Bool {
        portfolioPnL.dailyPnL >= 0
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onToggle()
                    }
                }

            if isExpanded {
                holdingsContent
                    .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
        .opacity(animateIn ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                animateIn = true
            }
        }
        .sheet(isPresented: $showHoldingDetail) {
            if let holding = selectedHolding {
                NavigationStack {
                    HoldingDetailView(
                        holding: holding,
                        quote: quotes[holding.symbol]
                    )
                }
            }
        }
    }

    // MARK: - 区块头部

    private var sectionHeader: some View {
        HStack(spacing: 12) {
            // 账户颜色标识
            Circle()
                .fill(portfolio.tagColor)
                .frame(width: 10, height: 10)

            // 账户名称
            VStack(alignment: .leading, spacing: 2) {
                Text(portfolio.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("\(portfolio.holdings.count) 持仓")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            // 数值 - 使用紧凑格式避免换行
            Text(portfolioPnL.totalValue.compactCurrencyFormatted(code: portfolio.baseCurrency))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // 涨跌幅徽章
            Text(portfolioPnL.dailyPnLPercent.percentFormatted())
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(minWidth: 65)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isPositive ? AppColors.profit : AppColors.loss)
                )

            // 展开/收起箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    // MARK: - 持仓内容

    @ViewBuilder
    private var holdingsContent: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.dividerColor)
                .frame(height: 1)
                .padding(.horizontal, 16)

            switch displayMode {
            case .basic:
                basicModeContent

            case .details:
                detailsModeContent

            case .holdings:
                holdingsModeContent
            }
        }
    }

    // MARK: - Basic 模式内容

    private var basicModeContent: some View {
        VStack(spacing: 0) {
            ForEach(portfolioPnL.holdingPnLs, id: \.holding.id) { holdingPnL in
                NavigationLink {
                    HoldingDetailView(
                        holding: holdingPnL.holding,
                        quote: quotes[holdingPnL.holding.symbol]
                    )
                } label: {
                    HoldingRow(
                        holding: holdingPnL.holding,
                        quote: quotes[holdingPnL.holding.symbol],
                        displayMode: .basic,
                        showPercent: showPercent
                    )
                }
                .buttonStyle(.plain)

                if holdingPnL.holding.id != portfolioPnL.holdingPnLs.last?.holding.id {
                    Rectangle()
                        .fill(AppColors.dividerColor)
                        .frame(height: 1)
                        .padding(.leading, 16)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Details 模式内容

    private var detailsModeContent: some View {
        let holdings = portfolioPnL.holdingPnLs.map(\.holding)

        return HoldingDetailsTable(
            holdings: holdings,
            quotes: quotes,
            showPercent: showPercent,
            onHoldingTap: { holding in
                selectedHolding = holding
                showHoldingDetail = true
            }
        )
        .frame(minHeight: CGFloat(holdings.count) * 56 + 48)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Holdings 模式内容

    private var holdingsModeContent: some View {
        VStack(spacing: 8) {
            ForEach(portfolioPnL.holdingPnLs, id: \.holding.id) { holdingPnL in
                ExpandableHoldingRow(
                    holding: holdingPnL.holding,
                    quote: quotes[holdingPnL.holding.symbol],
                    showPercent: showPercent
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                Text("需要 SwiftData 上下文预览")
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding()
        }
    }
}
