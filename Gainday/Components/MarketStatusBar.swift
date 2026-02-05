import SwiftUI

/// 极简风格的市场状态栏
struct MarketStatusBar: View {
    let quotes: [String: MarketDataService.QuoteData]

    private var marketStates: [(Market, MarketState)] {
        let marketSymbols: [(Market, String)] = [
            (.JP, "7203.T"),
            (.US, "AAPL"),
            (.CN, "600519.SS"),
            (.HK, "0700.HK"),
        ]

        return marketSymbols.compactMap { market, symbol in
            if let quote = quotes[symbol],
               let stateStr = quote.marketState,
               let state = MarketState(rawValue: stateStr) {
                return (market, state)
            }
            return nil
        }
    }

    var body: some View {
        if !marketStates.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("市场状态")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(marketStates, id: \.0) { market, state in
                            MarketStatusIndicator(market: market, state: state)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    MarketStatusBar(quotes: [:])
        .padding()
}
