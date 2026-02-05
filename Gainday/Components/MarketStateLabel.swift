import SwiftUI

/// 极简风格的市场状态标签
/// 只用颜色文字，不加背景
struct MarketStateLabel: View {
    let state: MarketState

    var body: some View {
        Text(state.displayName)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(state.color)
    }
}

/// 极简风格的市场状态指示器
struct MarketStatusIndicator: View {
    let market: Market
    let state: MarketState

    @State private var isGlowing = false

    var body: some View {
        HStack(spacing: 10) {
            // 状态点
            Circle()
                .fill(state.isTrading ? AppColors.profit : AppColors.textTertiary)
                .frame(width: 6, height: 6)
                .opacity(state.isTrading && isGlowing ? 0.5 : 1)
                .animation(
                    state.isTrading ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default,
                    value: isGlowing
                )

            // 市场信息
            VStack(alignment: .leading, spacing: 2) {
                Text(market.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Text(state.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(state.isTrading ? AppColors.profit : AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlass(cornerRadius: 12)
        .onAppear {
            if state.isTrading {
                isGlowing = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                MarketStateLabel(state: .pre)
                MarketStateLabel(state: .regular)
                MarketStateLabel(state: .post)
                MarketStateLabel(state: .closed)
            }

            Divider()

            HStack(spacing: 12) {
                MarketStatusIndicator(market: .JP, state: .closed)
                MarketStatusIndicator(market: .US, state: .regular)
            }
            HStack(spacing: 12) {
                MarketStatusIndicator(market: .CN, state: .regular)
                MarketStatusIndicator(market: .HK, state: .pre)
            }
        }
        .padding()
    }
}
