import SwiftUI

/// iPhone 股票 App 风格的投资组合头部
struct PortfolioHeaderView: View {
    let totalValue: Double
    let dailyPnL: Double
    let dailyPnLPercent: Double
    let unrealizedPnL: Double
    let unrealizedPnLPercent: Double
    let baseCurrency: String

    @State private var animateIn = false

    private var isPositive: Bool { dailyPnL >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 标题
            Text("投资组合")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)

            // 总值 - 大号白色数字
            Text(totalValue.currencyFormatted(code: baseCurrency))
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .contentTransition(.numericText())

            // 今日盈亏
            HStack(spacing: 8) {
                // 金额变化
                Text(dailyPnL.currencyFormatted(code: baseCurrency, showSign: true))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isPositive ? AppColors.profit : AppColors.loss)

                // 百分比徽章 - iPhone 股票 App 风格
                Text(dailyPnLPercent.percentFormatted())
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isPositive ? AppColors.profit : AppColors.loss)
                    )

                Text("今日")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
            }

            // 总盈亏 (次要信息)
            HStack(spacing: 4) {
                Text("总盈亏")
                    .foregroundStyle(AppColors.textSecondary)
                Text(unrealizedPnL.currencyFormatted(code: baseCurrency, showSign: true))
                    .foregroundStyle(unrealizedPnL >= 0 ? AppColors.profit : AppColors.loss)
                Text("(\(unrealizedPnLPercent.percentFormatted()))")
                    .foregroundStyle(AppColors.textSecondary)
            }
            .font(.system(size: 13))
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                animateIn = true
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PortfolioHeaderView(
            totalValue: 5234567,
            dailyPnL: 42340,
            dailyPnLPercent: 0.82,
            unrealizedPnL: 345000,
            unrealizedPnLPercent: 7.05,
            baseCurrency: "JPY"
        )

        PortfolioHeaderView(
            totalValue: 5234567,
            dailyPnL: -18500,
            dailyPnLPercent: -0.35,
            unrealizedPnL: -45000,
            unrealizedPnLPercent: -0.92,
            baseCurrency: "JPY"
        )
    }
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
