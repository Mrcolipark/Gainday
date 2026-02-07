import SwiftUI
import Charts

/// 极简风格的持仓行组件
struct HoldingRow: View {
    let holding: Holding
    let quote: MarketDataService.QuoteData?
    let displayMode: PortfolioDisplayMode
    let showPercent: Bool

    init(
        holding: Holding,
        quote: MarketDataService.QuoteData?,
        displayMode: PortfolioDisplayMode = .basic,
        showPercent: Bool = true
    ) {
        self.holding = holding
        self.quote = quote
        self.displayMode = displayMode
        self.showPercent = showPercent
    }

    // MARK: - 计算属性

    private var displaySymbol: String {
        holding.symbol
            .replacingOccurrences(of: ".T", with: "")
            .replacingOccurrences(of: ".SS", with: "")
            .replacingOccurrences(of: ".SZ", with: "")
    }

    private var currentPrice: Double {
        quote?.regularMarketPrice ?? 0
    }

    private var previousClose: Double {
        quote?.regularMarketPreviousClose ?? currentPrice
    }

    private var dailyChange: Double {
        currentPrice - previousClose
    }

    private var dailyChangePercent: Double {
        guard previousClose > 0 else { return 0 }
        return (dailyChange / previousClose) * 100
    }

    private var marketState: MarketState? {
        guard let stateStr = quote?.marketState else { return nil }
        return MarketState(rawValue: stateStr)
    }

    private var isUSStock: Bool {
        holding.marketEnum == .US
    }

    private var hasExtendedHoursData: Bool {
        guard isUSStock else { return false }
        switch marketState {
        case .pre, .prepre:
            return quote?.preMarketPrice != nil
        case .post, .postpost:
            return quote?.postMarketPrice != nil
        default:
            return false
        }
    }

    private var displayPrice: Double {
        if isUSStock, let state = marketState {
            switch state {
            case .pre, .prepre:
                return quote?.preMarketPrice ?? currentPrice
            case .post, .postpost:
                return quote?.postMarketPrice ?? currentPrice
            default:
                return currentPrice
            }
        }
        return currentPrice
    }

    private var displayChangePercent: Double {
        if isUSStock, let state = marketState {
            switch state {
            case .pre, .prepre:
                return quote?.preMarketChangePercent ?? dailyChangePercent
            case .post, .postpost:
                return quote?.postMarketChangePercent ?? dailyChangePercent
            default:
                return dailyChangePercent
            }
        }
        return dailyChangePercent
    }

    private var displayIsPositive: Bool {
        displayChangePercent >= 0
    }

    private var effectivePrice: Double {
        displayPrice
    }

    private var unrealizedPnL: Double {
        (effectivePrice - holding.averageCost) * holding.totalQuantity
    }

    private var unrealizedPnLPercent: Double {
        guard holding.averageCost > 0 else { return 0 }
        return (effectivePrice - holding.averageCost) / holding.averageCost * 100
    }

    private var marketValue: Double {
        effectivePrice * holding.totalQuantity
    }

    private var isPositive: Bool {
        dailyChangePercent >= 0
    }

    private var totalPnLPositive: Bool {
        unrealizedPnL >= 0
    }

    // MARK: - Body

    var body: some View {
        switch displayMode {
        case .basic:
            basicMode
        case .details:
            detailsMode
        case .holdings:
            holdingsMode
        }
    }

    // MARK: - Basic Mode (iPhone 股票 App 风格)

    private var basicMode: some View {
        HStack(spacing: 8) {
            // 左侧：股票代码和名称
            VStack(alignment: .leading, spacing: 2) {
                Text(displaySymbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(holding.name)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 右侧：价格和涨跌幅徽章
            HStack(spacing: 8) {
                // 价格 - 使用紧凑格式避免换行
                Text(displayPrice > 0 ? displayPrice.compactCurrencyFormatted(code: holding.currency) : "-")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // 涨跌幅徽章
                if displayPrice > 0 {
                    Text(String(format: "%+.2f%%", displayChangePercent))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 72)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(displayIsPositive ? AppColors.profit : AppColors.loss)
                        )
                }
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Details Mode

    private var detailsMode: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：股票信息和价格
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displaySymbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(holding.name)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // 价格和涨跌
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currentPrice.compactCurrencyFormatted(code: holding.currency))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()

                    // 涨跌幅徽章
                    Text(String(format: "%+.2f%%", dailyChangePercent))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isPositive ? AppColors.profit : AppColors.loss)
                        )
                }
            }

            // 指标区域 - 使用深色背景卡片
            if hasAnyMetric {
                HStack(spacing: 0) {
                    if let volume = quote?.regularMarketVolume, volume > 0 {
                        metricItem(label: "成交量".localized, value: volume.compactFormatted())
                        Spacer()
                    }
                    if let high = quote?.regularMarketDayHigh {
                        metricItem(label: "最高".localized, value: high.compactCurrencyFormatted(code: holding.currency))
                        Spacer()
                    }
                    if let low = quote?.regularMarketDayLow {
                        metricItem(label: "最低".localized, value: low.compactCurrencyFormatted(code: holding.currency))
                        Spacer()
                    }
                    if let high52 = quote?.fiftyTwoWeekHigh {
                        metricItem(label: "52周高".localized, value: high52.compactCurrencyFormatted(code: holding.currency))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppColors.elevatedSurface)
                )
            }
        }
        .padding(.vertical, 10)
    }

    private var hasAnyMetric: Bool {
        quote?.regularMarketVolume != nil ||
        quote?.regularMarketDayHigh != nil ||
        quote?.regularMarketDayLow != nil
    }

    private func metricItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    // MARK: - Holdings Mode

    private var holdingsMode: some View {
        VStack(spacing: 12) {
            // 头部：股票信息和市值
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displaySymbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("\(holding.totalQuantity.formattedQuantity)\("股".localized)")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(marketValue.compactCurrencyFormatted(code: holding.currency))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()

                    // 盈亏徽章
                    Text(unrealizedPnLPercent.percentFormatted())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(totalPnLPositive ? AppColors.profit : AppColors.loss)
                        )
                }
            }

            // 底部统计 - 深色背景
            HStack(spacing: 0) {
                statItem(label: "现价".localized, value: displayPrice.compactCurrencyFormatted(code: holding.currency))
                Spacer()
                statItem(label: "成本".localized, value: holding.averageCost.compactCurrencyFormatted(code: holding.currency))
                Spacer()
                statItem(label: "盈亏".localized, value: unrealizedPnL.compactCurrencyFormatted(code: holding.currency, showSign: true), color: totalPnLPositive ? AppColors.profit : AppColors.loss)
                Spacer()
                statItem(
                    label: "今日".localized,
                    value: String(format: "%+.2f%%", dailyChangePercent),
                    color: isPositive ? AppColors.profit : AppColors.loss
                )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppColors.elevatedSurface)
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private func statItem(label: String, value: String, color: Color = AppColors.textPrimary) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            Text("Basic Mode").font(.headline)
            HoldingRow(
                holding: Holding(symbol: "AAPL", name: "Apple Inc.", market: Market.US.rawValue),
                quote: nil,
                displayMode: .basic
            )
            .padding(.horizontal)

            Divider()

            Text("Details Mode").font(.headline)
            HoldingRow(
                holding: Holding(symbol: "7203.T", name: "トヨタ自動車", market: Market.JP.rawValue),
                quote: nil,
                displayMode: .details
            )
            .padding(.horizontal)

            Divider()

            Text("Holdings Mode").font(.headline)
            HoldingRow(
                holding: Holding(symbol: "MSFT", name: "Microsoft Corp.", market: Market.US.rawValue),
                quote: nil,
                displayMode: .holdings
            )
            .padding(.horizontal)
        }
        .padding()
    }
}
