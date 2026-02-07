import Foundation
import SwiftData
import SwiftUI

/// 测试数据生成器 - 仅用于开发调试
/// Debug tool for generating test data
struct TestDataGenerator {

    // MARK: - 汇率常量（用于换算到基准货币 JPY）
    private static let usdToJpy: Double = 150.0  // 1 USD = 150 JPY
    private static let cnyToJpy: Double = 21.0   // 1 CNY = 21 JPY

    /// 生成完整的测试数据集
    @MainActor
    static func generateAllTestData(modelContext: ModelContext) {
        // 1. 创建测试账户
        let portfolios = generateTestPortfolios(modelContext: modelContext)

        // 2. 为每个账户添加持仓和交易
        generateTestHoldings(portfolios: portfolios, modelContext: modelContext)

        // 3. 生成日历快照数据（过去90天）
        generateTestSnapshots(modelContext: modelContext)

        do {
            try modelContext.save()
            print("✅ Test data generated successfully!")
            print("   Portfolios: \(portfolios.count)")
            for p in portfolios {
                print("   - \(p.name): \(p.holdings.count) holdings")
            }
        } catch {
            print("❌ Failed to save test data: \(error)")
        }
    }

    /// 清除所有数据
    @MainActor
    static func clearAllData(modelContext: ModelContext) {
        do {
            try modelContext.delete(model: DailySnapshot.self)
            try modelContext.delete(model: Transaction.self)
            try modelContext.delete(model: Holding.self)
            try modelContext.delete(model: Portfolio.self)
            try modelContext.save()
            print("🗑️ All data cleared!")
        } catch {
            print("Error clearing data: \(error)")
        }
    }

    // MARK: - Private Methods

    @MainActor
    private static func generateTestPortfolios(modelContext: ModelContext) -> [Portfolio] {
        let portfoliosData: [(name: String, type: String, currency: String, color: String)] = [
            ("乐天证券", AccountType.normal.rawValue, BaseCurrency.JPY.rawValue, "blue"),
            ("乐天证券 NISA", AccountType.nisa_tsumitate.rawValue, BaseCurrency.JPY.rawValue, "teal"),
            ("招商证券", AccountType.normal.rawValue, BaseCurrency.CNY.rawValue, "red"),
        ]

        var portfolios: [Portfolio] = []
        for (index, data) in portfoliosData.enumerated() {
            let portfolio = Portfolio(
                name: data.name,
                accountType: data.type,
                baseCurrency: data.currency,
                sortOrder: index,
                colorTag: data.color
            )
            modelContext.insert(portfolio)
            portfolios.append(portfolio)
        }

        return portfolios
    }

    @MainActor
    private static func generateTestHoldings(portfolios: [Portfolio], modelContext: ModelContext) {
        // 乐天证券 - 日股 + 美股
        if let rakuten = portfolios.first(where: { $0.name == "乐天证券" }) {
            // 日股
            let jpStocks: [(symbol: String, name: String, qty: Double, price: Double, date: String)] = [
                ("285A.T", "キオクシアHD", 2, 13875, "20260114"),
                ("285A.T", "キオクシアHD", 1, 20390, "20260203"),
                ("285A.T", "キオクシアHD", 1, 20155, "20260203"),
                ("7974.T", "任天堂", 10, 9979, "20260113"),
                ("7013.T", "IHI", 27, 3540, "20260113"),
                ("7013.T", "IHI", 3, 3479, "20260128"),
                ("7013.T", "IHI", 3, 3483, "20260113"),
                ("7013.T", "IHI", 17, 3484, "20260114"),
            ]

            // 按股票代码分组创建持仓
            var jpHoldingsMap: [String: Holding] = [:]
            for stock in jpStocks {
                let holding: Holding
                if let existing = jpHoldingsMap[stock.symbol] {
                    holding = existing
                } else {
                    holding = Holding(
                        symbol: stock.symbol,
                        name: stock.name,
                        assetType: AssetType.stock.rawValue,
                        market: Market.JP.rawValue
                    )
                    holding.portfolio = rakuten
                    modelContext.insert(holding)
                    rakuten.holdings.append(holding)
                    jpHoldingsMap[stock.symbol] = holding
                }

                // 解析日期
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd"
                let tradeDate = dateFormatter.date(from: stock.date) ?? Date()

                let tx = Transaction(
                    type: TransactionType.buy.rawValue,
                    date: tradeDate,
                    quantity: stock.qty,
                    price: stock.price,
                    fee: 0,
                    currency: "JPY"
                )
                modelContext.insert(tx)
                holding.transactions.append(tx)
            }

            // 美股
            let usStocks: [(symbol: String, name: String, qty: Double, price: Double, date: String)] = [
                ("MUU", "MicroSectors Gold Miners 3X", 1, 216.05, "20260203"),
                ("MAGS", "Roundhill Magnificent Seven ETF", 10, 65.6, "20260127"),
                ("ONDS", "Ondas Holdings", 15, 11.185, "20260127"),
                ("ONDS", "Ondas Holdings", 45, 12.8292, "20260121"),
            ]

            var usHoldingsMap: [String: Holding] = [:]
            for stock in usStocks {
                let holding: Holding
                if let existing = usHoldingsMap[stock.symbol] {
                    holding = existing
                } else {
                    holding = Holding(
                        symbol: stock.symbol,
                        name: stock.name,
                        assetType: AssetType.stock.rawValue,
                        market: Market.US.rawValue
                    )
                    holding.portfolio = rakuten
                    modelContext.insert(holding)
                    rakuten.holdings.append(holding)
                    usHoldingsMap[stock.symbol] = holding
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd"
                let tradeDate = dateFormatter.date(from: stock.date) ?? Date()

                let tx = Transaction(
                    type: TransactionType.buy.rawValue,
                    date: tradeDate,
                    quantity: stock.qty,
                    price: stock.price,
                    fee: 0,
                    currency: "USD"
                )
                modelContext.insert(tx)
                holding.transactions.append(tx)
            }
        }

        // 乐天证券 NISA - 積立投資信託
        if let nisa = portfolios.first(where: { $0.name == "乐天证券 NISA" }) {
            // NISA積立定投基金 (每月24日定投)
            // 使用真实的8位基金代码，App会通过JapanFundService获取报价
            let nisaFunds: [(symbol: String, name: String, monthlyAmount: Double)] = [
                ("03311172", "eMAXIS Slim 先進国株式インデックス", 25000),        // 先進国株式(除く日本同系列)
                ("04311214", "iFreeNEXT FANG+インデックス", 25000),              // FANG+ ETF
                ("89311199", "楽天・全米株式インデックス・ファンド", 50000),        // 楽天VTI
            ]

            let calendar = Calendar.current
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"

            for fund in nisaFunds {
                let holding = Holding(
                    symbol: fund.symbol,
                    name: fund.name,
                    assetType: AssetType.fund.rawValue,
                    market: Market.JP_FUND.rawValue
                )
                holding.portfolio = nisa
                modelContext.insert(holding)
                nisa.holdings.append(holding)

                // 生成过去几个月的定投交易记录（模拟从2025年10月开始定投）
                let startDate = dateFormatter.date(from: "20251024") ?? Date()
                var currentDate = startDate

                while currentDate <= Date() {
                    // 基准价约10000-30000日元/口，每月波动
                    let basePrice = Double.random(in: 18000...25000)
                    let quantity = fund.monthlyAmount / basePrice

                    let tx = Transaction(
                        type: TransactionType.buy.rawValue,
                        date: currentDate,
                        quantity: quantity,
                        price: basePrice,
                        fee: 0,
                        currency: "JPY"
                    )
                    modelContext.insert(tx)
                    holding.transactions.append(tx)

                    // 下个月24日
                    currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
                }
            }
        }

        // 招商证券 - A股
        if let zhaoshang = portfolios.first(where: { $0.name == "招商证券" }) {
            let cnStocks: [(symbol: String, name: String, qty: Double, price: Double, date: String)] = [
                ("603306.SS", "华懋科技", 100, 66.6, "20260115"),
            ]

            for stock in cnStocks {
                let holding = Holding(
                    symbol: stock.symbol,
                    name: stock.name,
                    assetType: AssetType.stock.rawValue,
                    market: Market.CN.rawValue
                )
                holding.portfolio = zhaoshang
                modelContext.insert(holding)
                zhaoshang.holdings.append(holding)

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd"
                let tradeDate = dateFormatter.date(from: stock.date) ?? Date()

                let tx = Transaction(
                    type: TransactionType.buy.rawValue,
                    date: tradeDate,
                    quantity: stock.qty,
                    price: stock.price,
                    fee: 0,
                    currency: "CNY"
                )
                modelContext.insert(tx)
                holding.transactions.append(tx)
            }
        }
    }

    @MainActor
    private static func generateTestSnapshots(modelContext: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 基于实际持仓计算基准值（全部换算成日元）
        // ========================================
        // 日股 (JPY):
        //   285A.T: 4股 × ¥19095 = ¥76,380
        //   7974.T: 10股 × ¥8441 = ¥84,410
        //   7013.T: 50股 × ¥3946 = ¥197,300
        //   小计: ¥358,090
        //
        // 美股 (USD → JPY, 汇率 150):
        //   MUU: 1股 × $175 = $175 → ¥26,250
        //   MAGS: 10股 × $62.72 = $627.2 → ¥94,080
        //   ONDS: 60股 × $9.29 = $557.4 → ¥83,610
        //   小计: $1,359.6 → ¥203,940
        //
        // A股 (CNY → JPY, 汇率 21):
        //   603306.SS: 100股 × ¥77.4 = ¥7,740 CNY → ¥162,540 JPY
        //
        // NISA定投 (JPY):
        //   约4个月 × ¥100,000 = ¥400,000
        //
        // 总计: ¥358,090 + ¥203,940 + ¥162,540 + ¥400,000 = ¥1,124,570
        // ========================================

        // 各资产原始货币成本
        let jpStockCostJPY: Double = 358_000      // 日股成本 (JPY)
        let usStockCostUSD: Double = 1_360        // 美股成本 (USD)
        let cnStockCostCNY: Double = 6_660        // A股成本 (CNY)
        let nisaFundCostJPY: Double = 400_000     // NISA基金成本 (JPY)

        // 换算成日元的总成本
        let totalCostJPY = jpStockCostJPY
            + (usStockCostUSD * usdToJpy)
            + (cnStockCostCNY * cnyToJpy)
            + nisaFundCostJPY

        // 生成过去90天的快照数据
        var cumulativePnL: Double = 0

        for daysAgo in (0...90).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }

            // 跳过周末
            let weekday = calendar.component(.weekday, from: date)
            if weekday == 1 || weekday == 7 { continue }

            // 各资产类别独立的日收益率 (-3% ~ +3%)
            let jpPnLPercent = Double.random(in: -3.0...3.0)
            let usPnLPercent = Double.random(in: -4.0...4.0)  // 美股波动稍大
            let cnPnLPercent = Double.random(in: -5.0...5.0)  // A股波动更大
            let nisaPnLPercent = Double.random(in: -2.0...2.0) // 基金波动较小

            // 计算各资产当日盈亏（换算成JPY）
            let jpPnL = jpStockCostJPY * jpPnLPercent / 100
            let usPnL = (usStockCostUSD * usdToJpy) * usPnLPercent / 100
            let cnPnL = (cnStockCostCNY * cnyToJpy) * cnPnLPercent / 100
            let nisaPnL = nisaFundCostJPY * nisaPnLPercent / 100

            let dailyPnL = jpPnL + usPnL + cnPnL + nisaPnL
            let dailyPnLPercent = (dailyPnL / totalCostJPY) * 100

            cumulativePnL += dailyPnL

            let totalValue = totalCostJPY + cumulativePnL

            // 创建分类明细（value/cost/pnl 全部为 JPY 计价，currency 标记原始货币）
            let breakdown: [AssetBreakdown] = [
                AssetBreakdown(assetType: AssetType.stock.rawValue,
                              value: jpStockCostJPY + jpPnL * Double(90 - daysAgo) / 90,
                              cost: jpStockCostJPY,
                              pnl: jpPnL,
                              currency: "JPY"),
                AssetBreakdown(assetType: AssetType.fund.rawValue,
                              value: nisaFundCostJPY + nisaPnL * Double(90 - daysAgo) / 90,
                              cost: nisaFundCostJPY,
                              pnl: nisaPnL,
                              currency: "JPY"),
                AssetBreakdown(assetType: AssetType.stock.rawValue,
                              value: (usStockCostUSD * usdToJpy) + usPnL * Double(90 - daysAgo) / 90,
                              cost: usStockCostUSD * usdToJpy,  // 成本也换算成JPY
                              pnl: usPnL,
                              currency: "USD"),
                AssetBreakdown(assetType: AssetType.stock.rawValue,
                              value: (cnStockCostCNY * cnyToJpy) + cnPnL * Double(90 - daysAgo) / 90,
                              cost: cnStockCostCNY * cnyToJpy,  // 成本也换算成JPY
                              pnl: cnPnL,
                              currency: "CNY"),
            ]

            let snapshot = DailySnapshot(
                date: date,
                totalValue: totalValue,
                totalCost: totalCostJPY,
                dailyPnL: dailyPnL,
                dailyPnLPercent: dailyPnLPercent,
                cumulativePnL: cumulativePnL
            )
            snapshot.setBreakdown(breakdown)

            modelContext.insert(snapshot)
        }
    }
}

// MARK: - Debug View for Settings

struct DebugDataSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showConfirmClear = false
    @State private var showConfirmGenerate = false

    var body: some View {
        VStack(spacing: 0) {
            // 生成测试数据
            Button {
                showConfirmGenerate = true
            } label: {
                HStack(spacing: 12) {
                    debugIcon("plus.square.fill.on.square.fill", color: AppColors.profit)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("生成测试数据")
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("创建测试账户和90天日历数据")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .alert("生成测试数据", isPresented: $showConfirmGenerate) {
                Button("取消", role: .cancel) {}
                Button("生成") {
                    TestDataGenerator.generateAllTestData(modelContext: modelContext)
                }
            } message: {
                Text("将创建乐天证券(日股+美股)、NISA定投、招商证券(A股)和90天日历数据")
            }

            Divider()
                .background(AppColors.dividerColor)
                .padding(.leading, 60)

            // 清除所有数据
            Button {
                showConfirmClear = true
            } label: {
                HStack(spacing: 12) {
                    debugIcon("trash.fill", color: AppColors.loss)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("清除所有数据")
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.loss)

                        Text("删除所有账户、持仓和交易记录")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .alert("确认清除", isPresented: $showConfirmClear) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    TestDataGenerator.clearAllData(modelContext: modelContext)
                }
            } message: {
                Text("此操作将删除所有账户、持仓、交易和日历数据，且无法恢复")
            }
        }
    }

    private func debugIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 32, height: 32)
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
