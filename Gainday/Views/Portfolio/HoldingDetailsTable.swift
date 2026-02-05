import SwiftUI

/// iPhone 股票 App 风格的横向同步滚动数据表格
/// Details 模式专用 - 表头和所有行同步横向滚动
struct HoldingDetailsTable: View {
    let holdings: [Holding]
    let quotes: [String: MarketDataService.QuoteData]
    let showPercent: Bool
    let onHoldingTap: (Holding) -> Void

    // 列定义
    private let columns: [TableColumn] = [
        TableColumn(id: "price", title: "价格", width: 75),
        TableColumn(id: "change", title: "涨跌", width: 70),
        TableColumn(id: "changePercent", title: "涨跌%", width: 65),
        TableColumn(id: "marketCap", title: "市值", width: 70),
        TableColumn(id: "pe", title: "P/E", width: 50),
        TableColumn(id: "volume", title: "成交量", width: 65),
        TableColumn(id: "high52w", title: "52周高", width: 75),
        TableColumn(id: "low52w", title: "52周低", width: 75),
        TableColumn(id: "divYield", title: "股息率", width: 60),
        TableColumn(id: "eps", title: "EPS", width: 55),
    ]

    struct TableColumn: Identifiable {
        let id: String
        let title: String
        let width: CGFloat
    }

    private var totalScrollWidth: CGFloat {
        columns.reduce(0) { $0 + $1.width } + 12 // +12 for trailing padding
    }

    var body: some View {
        GeometryReader { geometry in
            let fixedWidth: CGFloat = 90
            let scrollableWidth = geometry.size.width - fixedWidth - 1 // -1 for separator

            HStack(spacing: 0) {
                // 固定左侧列：Symbol
                fixedColumn(width: fixedWidth)

                // 垂直分隔线
                Rectangle()
                    .fill(AppColors.dividerColor)
                    .frame(width: 1)

                // 可滚动右侧：表头 + 数据行 同步滚动
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 表头行
                        scrollableHeader

                        // 水平分隔线
                        Rectangle()
                            .fill(AppColors.dividerColor)
                            .frame(height: 1)

                        // 数据行（垂直滚动）
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(holdings) { holding in
                                    scrollableRow(holding: holding)

                                    if holding.id != holdings.last?.id {
                                        Rectangle()
                                            .fill(AppColors.dividerColor.opacity(0.5))
                                            .frame(height: 1)
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: totalScrollWidth)
                }
                .frame(width: scrollableWidth)
            }
        }
        .background(AppColors.cardSurface)
    }

    // MARK: - 固定左侧列

    private func fixedColumn(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            // 表头
            Text("股票")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: width, height: 36, alignment: .leading)
                .padding(.leading, 12)
                .background(AppColors.elevatedSurface)

            // 分隔线
            Rectangle()
                .fill(AppColors.dividerColor)
                .frame(height: 1)

            // 数据列
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(holdings) { holding in
                        fixedColumnCell(holding: holding, width: width)

                        if holding.id != holdings.last?.id {
                            Rectangle()
                                .fill(AppColors.dividerColor.opacity(0.5))
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .frame(width: width)
    }

    private func fixedColumnCell(holding: Holding, width: CGFloat) -> some View {
        Button {
            onHoldingTap(holding)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.symbol
                    .replacingOccurrences(of: ".T", with: "")
                    .replacingOccurrences(of: ".SS", with: "")
                    .replacingOccurrences(of: ".SZ", with: ""))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(holding.name)
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: width, height: 44, alignment: .leading)
            .padding(.leading, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 可滚动表头

    private var scrollableHeader: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                Text(column.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: column.width, alignment: .trailing)
            }
        }
        .frame(height: 36)
        .padding(.trailing, 12)
        .background(AppColors.elevatedSurface)
    }

    // MARK: - 可滚动数据行

    private func scrollableRow(holding: Holding) -> some View {
        let quote = quotes[holding.symbol]
        let currentPrice = quote?.regularMarketPrice ?? 0
        let previousClose = quote?.regularMarketPreviousClose ?? currentPrice
        let change = currentPrice - previousClose
        let changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0
        let isPositive = change >= 0

        return Button {
            onHoldingTap(holding)
        } label: {
            HStack(spacing: 0) {
                // 价格
                Text(currentPrice > 0 ? currentPrice.compactCurrencyFormatted(code: holding.currency) : "-")
                    .frame(width: columns[0].width, alignment: .trailing)
                    .foregroundStyle(AppColors.textPrimary)

                // 涨跌
                Text(currentPrice > 0 ? change.compactCurrencyFormatted(code: holding.currency, showSign: true) : "-")
                    .frame(width: columns[1].width, alignment: .trailing)
                    .foregroundStyle(isPositive ? AppColors.profit : AppColors.loss)

                // 涨跌%
                Text(currentPrice > 0 ? changePercent.percentFormatted() : "-")
                    .frame(width: columns[2].width, alignment: .trailing)
                    .foregroundStyle(isPositive ? AppColors.profit : AppColors.loss)

                // 市值
                Text(quote?.marketCap.map { $0.compactFormatted() } ?? "-")
                    .frame(width: columns[3].width, alignment: .trailing)
                    .foregroundStyle(AppColors.textPrimary)

                // P/E
                Text(quote?.trailingPE.map { String(format: "%.1f", $0) } ?? "-")
                    .frame(width: columns[4].width, alignment: .trailing)
                    .foregroundStyle(AppColors.textPrimary)

                // 成交量
                Text(quote?.regularMarketVolume.map { $0.compactFormatted() } ?? "-")
                    .frame(width: columns[5].width, alignment: .trailing)
                    .foregroundStyle(AppColors.textPrimary)

                // 52周高
                Text(quote?.fiftyTwoWeekHigh.map { $0.compactCurrencyFormatted(code: holding.currency) } ?? "-")
                    .frame(width: columns[6].width, alignment: .trailing)
                    .foregroundStyle(AppColors.textPrimary)

                // 52周低
                Text(quote?.fiftyTwoWeekLow.map { $0.compactCurrencyFormatted(code: holding.currency) } ?? "-")
                    .frame(width: columns[7].width, alignment: .trailing)
                    .foregroundStyle(AppColors.textPrimary)

                // 股息率
                Text(quote?.dividendYield.flatMap { $0 > 0 ? String(format: "%.1f%%", $0) : nil } ?? "-")
                    .frame(width: columns[8].width, alignment: .trailing)
                    .foregroundStyle(AppColors.textPrimary)

                // EPS
                Text(quote?.epsTrailingTwelveMonths.map { String(format: "%.2f", $0) } ?? "-")
                    .frame(width: columns[9].width, alignment: .trailing)
                    .foregroundStyle(AppColors.textPrimary)
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .frame(height: 44)
            .padding(.trailing, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        Text("需要 SwiftData 上下文预览")
            .foregroundStyle(AppColors.textSecondary)
    }
    .preferredColorScheme(.dark)
}
