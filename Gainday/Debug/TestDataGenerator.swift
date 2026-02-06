import Foundation
import SwiftData
import SwiftUI

/// 测试数据生成器 - 仅用于开发调试
/// Debug tool for generating test data
struct TestDataGenerator {

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
            ("楽天証券", AccountType.normal.rawValue, BaseCurrency.JPY.rawValue, "blue"),
            ("SBI証券 NISA", AccountType.nisa_tsumitate.rawValue, BaseCurrency.JPY.rawValue, "teal"),
            ("Firstrade", AccountType.normal.rawValue, BaseCurrency.USD.rawValue, "orange"),
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
        // 日本股票 - 楽天証券
        if let rakuten = portfolios.first(where: { $0.name == "楽天証券" }) {
            let jpStocks: [(symbol: String, name: String, qty: Double, price: Double)] = [
                ("7203.T", "トヨタ自動車", 100, 2850),
                ("9984.T", "ソフトバンクグループ", 50, 8500),
                ("6758.T", "ソニーグループ", 30, 14200),
                ("8306.T", "三菱UFJ銀行", 200, 1650),
            ]

            for stock in jpStocks {
                let holding = Holding(
                    symbol: stock.symbol,
                    name: stock.name,
                    assetType: AssetType.stock.rawValue,
                    market: Market.JP.rawValue
                )
                holding.portfolio = rakuten  // Explicitly set inverse relationship
                modelContext.insert(holding)
                rakuten.holdings.append(holding)

                // 添加买入交易
                let tx = Transaction(
                    type: TransactionType.buy.rawValue,
                    date: Date().adding(days: -Int.random(in: 30...180)),
                    quantity: stock.qty,
                    price: stock.price * Double.random(in: 0.9...1.0), // 买入价略低
                    fee: 0,
                    currency: "JPY"
                )
                modelContext.insert(tx)
                holding.transactions.append(tx)
            }
        }

        // NISA - SBI証券 (ETF + 投資信託)
        if let sbi = portfolios.first(where: { $0.name.contains("NISA") }) {
            // 上場ETF
            let nisaETFs: [(symbol: String, name: String, qty: Double, price: Double)] = [
                ("1306.T", "TOPIX ETF", 50, 2800),
                ("2558.T", "S&P500 ETF", 30, 22500),
            ]

            for stock in nisaETFs {
                let holding = Holding(
                    symbol: stock.symbol,
                    name: stock.name,
                    assetType: AssetType.fund.rawValue,
                    market: Market.JP.rawValue
                )
                holding.portfolio = sbi
                modelContext.insert(holding)
                sbi.holdings.append(holding)

                let tx = Transaction(
                    type: TransactionType.buy.rawValue,
                    date: Date().adding(days: -Int.random(in: 60...365)),
                    quantity: stock.qty,
                    price: stock.price * Double.random(in: 0.85...0.95),
                    fee: 0,
                    currency: "JPY"
                )
                modelContext.insert(tx)
                holding.transactions.append(tx)
            }

            // 投資信託 (非上場)
            let nisaFunds: [(symbol: String, name: String, qty: Double, price: Double)] = [
                ("0331418A", "eMAXIS Slim 米国株式(S&P500)", 100, 28500),
                ("03311187", "eMAXIS Slim 全世界株式", 80, 24800),
            ]

            for fund in nisaFunds {
                let holding = Holding(
                    symbol: fund.symbol,
                    name: fund.name,
                    assetType: AssetType.fund.rawValue,
                    market: Market.JP_FUND.rawValue  // 使用新的投信市场类型
                )
                holding.portfolio = sbi
                modelContext.insert(holding)
                sbi.holdings.append(holding)

                let tx = Transaction(
                    type: TransactionType.buy.rawValue,
                    date: Date().adding(days: -Int.random(in: 90...400)),
                    quantity: fund.qty,
                    price: fund.price * Double.random(in: 0.80...0.90),
                    fee: 0,
                    currency: "JPY"
                )
                modelContext.insert(tx)
                holding.transactions.append(tx)
            }
        }

        // 美股 - Firstrade
        if let firstrade = portfolios.first(where: { $0.name == "Firstrade" }) {
            let usStocks: [(symbol: String, name: String, qty: Double, price: Double)] = [
                ("AAPL", "Apple Inc.", 50, 185),
                ("MSFT", "Microsoft Corp.", 30, 420),
                ("GOOGL", "Alphabet Inc.", 20, 175),
                ("NVDA", "NVIDIA Corp.", 15, 880),
                ("TSLA", "Tesla Inc.", 25, 245),
            ]

            for stock in usStocks {
                let holding = Holding(
                    symbol: stock.symbol,
                    name: stock.name,
                    assetType: AssetType.stock.rawValue,
                    market: Market.US.rawValue
                )
                holding.portfolio = firstrade
                modelContext.insert(holding)
                firstrade.holdings.append(holding)

                let tx = Transaction(
                    type: TransactionType.buy.rawValue,
                    date: Date().adding(days: -Int.random(in: 30...200)),
                    quantity: stock.qty,
                    price: stock.price * Double.random(in: 0.8...0.95),
                    fee: 0,
                    currency: "USD"
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

        // 生成过去90天的快照数据
        var cumulativePnL: Double = 0
        let baseTotalValue: Double = 5_000_000 // 500万日元基准

        for daysAgo in (0...90).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }

            // 跳过周末
            let weekday = calendar.component(.weekday, from: date)
            if weekday == 1 || weekday == 7 { continue }

            // 随机生成当日盈亏 (-3% ~ +3%)
            let dailyPnLPercent = Double.random(in: -3.0...3.0)
            let dailyPnL = baseTotalValue * dailyPnLPercent / 100

            cumulativePnL += dailyPnL

            let totalValue = baseTotalValue + cumulativePnL
            let totalCost = baseTotalValue * 0.9 // 假设成本是市值的90%

            // 创建分类明细
            let breakdown: [AssetBreakdown] = [
                AssetBreakdown(assetType: AssetType.stock.rawValue, value: totalValue * 0.7, cost: totalCost * 0.7, pnl: dailyPnL * 0.7, currency: "JPY"),
                AssetBreakdown(assetType: AssetType.fund.rawValue, value: totalValue * 0.2, cost: totalCost * 0.2, pnl: dailyPnL * 0.2, currency: "JPY"),
                AssetBreakdown(assetType: AssetType.stock.rawValue, value: totalValue * 0.1, cost: totalCost * 0.1, pnl: dailyPnL * 0.1, currency: "USD"),
            ]

            let snapshot = DailySnapshot(
                date: date,
                totalValue: totalValue,
                totalCost: totalCost,
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
                Text("将创建3个测试账户、多个持仓和90天的日历数据")
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
