import Foundation
import SwiftData

/// CSV 导入服务
struct CSVImportService {

    struct ImportResult {
        let portfoliosCreated: Int
        let holdingsCreated: Int
        let transactionsCreated: Int
        let errors: [String]
    }

    /// 导入 CSV 数据
    /// CSV 格式: Account,Symbol,Name,Type,Market,TransactionType,Date,Quantity,Price,Fee,Currency,Note
    @MainActor
    static func importCSV(
        from url: URL,
        modelContext: ModelContext
    ) throws -> ImportResult {
        // 读取文件
        guard url.startAccessingSecurityScopedResource() else {
            throw CSVImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        guard lines.count > 1 else {
            throw CSVImportError.emptyFile
        }

        // 解析 header
        let header = parseCSVLine(lines[0])
        let expectedHeaders = ["Account", "Symbol", "Name", "Type", "Market", "TransactionType", "Date", "Quantity", "Price", "Fee", "Currency", "Note"]

        // 验证 header（至少需要核心字段）
        let requiredFields = ["Account", "Symbol", "Name", "TransactionType", "Date", "Quantity", "Price"]
        for field in requiredFields {
            if !header.contains(field) {
                throw CSVImportError.missingColumn(field)
            }
        }

        // 创建索引映射
        var columnIndex: [String: Int] = [:]
        for (index, col) in header.enumerated() {
            columnIndex[col] = index
        }

        // 缓存已创建的 Portfolio 和 Holding
        var portfolioCache: [String: Portfolio] = [:]
        var holdingCache: [String: Holding] = [:]  // key: "accountName|symbol"
        var errors: [String] = []

        var portfoliosCreated = 0
        var holdingsCreated = 0
        var transactionsCreated = 0

        // 解析数据行
        for (lineIndex, line) in lines.dropFirst().enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let row = parseCSVLine(trimmed)
            guard row.count >= requiredFields.count else {
                errors.append("行 \(lineIndex + 2): 列数不足")
                continue
            }

            // 获取字段值
            guard let accountIdx = columnIndex["Account"],
                  let symbolIdx = columnIndex["Symbol"],
                  let nameIdx = columnIndex["Name"],
                  let txTypeIdx = columnIndex["TransactionType"],
                  let dateIdx = columnIndex["Date"],
                  let qtyIdx = columnIndex["Quantity"],
                  let priceIdx = columnIndex["Price"] else {
                continue
            }

            let accountName = row[accountIdx]
            let symbol = row[symbolIdx]
            let name = row[nameIdx]
            let txTypeStr = row[txTypeIdx]
            let dateStr = row[dateIdx]
            let qtyStr = row[qtyIdx]
            let priceStr = row[priceIdx]

            // 可选字段
            let assetType = columnIndex["Type"].flatMap { row.indices.contains($0) ? row[$0] : nil } ?? AssetType.stock.rawValue
            let market = columnIndex["Market"].flatMap { row.indices.contains($0) ? row[$0] : nil } ?? Market.JP.rawValue
            let feeStr = columnIndex["Fee"].flatMap { row.indices.contains($0) ? row[$0] : nil } ?? "0"
            let currency = columnIndex["Currency"].flatMap { row.indices.contains($0) ? row[$0] : nil } ?? "JPY"
            let note = columnIndex["Note"].flatMap { row.indices.contains($0) ? row[$0] : nil } ?? ""

            // 验证必填字段
            guard !accountName.isEmpty, !symbol.isEmpty, !name.isEmpty else {
                errors.append("行 \(lineIndex + 2): 账户/代码/名称不能为空")
                continue
            }

            // 解析交易类型
            let txType: TransactionType
            switch txTypeStr.lowercased() {
            case "buy", "买入": txType = .buy
            case "sell", "卖出": txType = .sell
            case "dividend", "分红": txType = .dividend
            default:
                errors.append("行 \(lineIndex + 2): 无效的交易类型 '\(txTypeStr)'")
                continue
            }

            // 解析日期
            guard let date = parseDate(dateStr) else {
                errors.append("行 \(lineIndex + 2): 无效的日期格式 '\(dateStr)'")
                continue
            }

            // 解析数量和价格
            guard let quantity = Double(qtyStr), quantity > 0 else {
                errors.append("行 \(lineIndex + 2): 无效的数量 '\(qtyStr)'")
                continue
            }

            guard let price = Double(priceStr), price >= 0 else {
                errors.append("行 \(lineIndex + 2): 无效的价格 '\(priceStr)'")
                continue
            }

            let fee = Double(feeStr) ?? 0

            // 获取或创建 Portfolio
            let portfolio: Portfolio
            if let cached = portfolioCache[accountName] {
                portfolio = cached
            } else {
                // 查找现有 Portfolio
                let predicate = #Predicate<Portfolio> { $0.name == accountName }
                let descriptor = FetchDescriptor<Portfolio>(predicate: predicate)
                if let existing = try? modelContext.fetch(descriptor).first {
                    portfolio = existing
                } else {
                    // 创建新 Portfolio
                    portfolio = Portfolio(
                        name: accountName,
                        accountType: AccountType.normal.rawValue,
                        baseCurrency: currency,
                        colorTag: "blue"
                    )
                    modelContext.insert(portfolio)
                    portfoliosCreated += 1
                }
                portfolioCache[accountName] = portfolio
            }

            // 获取或创建 Holding
            let holdingKey = "\(accountName)|\(symbol)"
            let holding: Holding
            if let cached = holdingCache[holdingKey] {
                holding = cached
            } else {
                // 查找现有 Holding
                if let existing = portfolio.holdings.first(where: { $0.symbol == symbol }) {
                    holding = existing
                } else {
                    // 创建新 Holding
                    holding = Holding(
                        symbol: symbol,
                        name: name,
                        assetType: assetType,
                        market: market
                    )
                    holding.portfolio = portfolio
                    portfolio.holdings.append(holding)
                    holdingsCreated += 1
                }
                holdingCache[holdingKey] = holding
            }

            // 创建 Transaction
            let transaction = Transaction(
                type: txType.rawValue,
                date: date,
                quantity: quantity,
                price: price,
                fee: fee,
                currency: currency,
                note: note
            )
            transaction.holding = holding
            holding.transactions.append(transaction)
            modelContext.insert(transaction)
            transactionsCreated += 1
        }

        // 保存
        try modelContext.save()

        return ImportResult(
            portfoliosCreated: portfoliosCreated,
            holdingsCreated: holdingsCreated,
            transactionsCreated: transactionsCreated,
            errors: errors
        )
    }

    // MARK: - Helpers

    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current.trimmingCharacters(in: .whitespaces))

        return result
    }

    private static func parseDate(_ str: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy/MM/dd"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MM/dd/yyyy"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "dd/MM/yyyy"
                return f
            }(),
        ]

        for formatter in formatters {
            if let date = formatter.date(from: str) {
                return date
            }
        }
        return nil
    }
}

enum CSVImportError: LocalizedError {
    case accessDenied
    case emptyFile
    case missingColumn(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "无法访问文件"
        case .emptyFile:
            return "CSV 文件为空"
        case .missingColumn(let col):
            return "缺少必需列: \(col)"
        case .parseError(let msg):
            return "解析错误: \(msg)"
        }
    }
}
