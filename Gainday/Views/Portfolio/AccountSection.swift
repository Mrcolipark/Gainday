import SwiftUI

struct AccountSection: View {
    let portfolio: Portfolio
    let quotes: [String: MarketDataService.QuoteData]

    private var totalValue: Double {
        portfolio.holdings.reduce(0) { result, holding in
            let qty = holding.totalQuantity
            let price = quotes[holding.symbol]?.regularMarketPrice ?? 0
            return result + qty * price
        }
    }

    private var dailyPnL: Double {
        portfolio.holdings.reduce(0) { result, holding in
            let qty = holding.totalQuantity
            guard let q = quotes[holding.symbol],
                  let price = q.regularMarketPrice,
                  let prevClose = q.regularMarketPreviousClose else { return result }
            return result + (price - prevClose) * qty
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [portfolio.tagColor, portfolio.tagColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(portfolio.tagColor.opacity(0.3))
                    .frame(width: 18, height: 18)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(portfolio.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    Text(portfolio.accountTypeEnum.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("\(portfolio.holdings.count) 只持仓")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(totalValue.currencyFormatted(code: portfolio.baseCurrency))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .monospacedDigit()
                HStack(spacing: 3) {
                    Circle()
                        .fill(dailyPnL >= 0 ? Color.green : Color.red)
                        .frame(width: 4, height: 4)
                    PnLText(dailyPnL, currencyCode: portfolio.baseCurrency, style: .caption)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    AccountSection(
        portfolio: Portfolio(name: "楽天証券", baseCurrency: "JPY"),
        quotes: [:]
    )
}
