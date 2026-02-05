import Foundation

/// 日本投資信託数据服务
/// 从Yahoo Finance Japan抓取投信基準価額
actor JapanFundService {
    static let shared = JapanFundService()

    private let session: URLSession

    // Yahoo Finance Japan API
    private let baseURL = "https://finance.yahoo.co.jp/quote/"

    // Minkabu as backup source
    private let minkabuURL = "https://itf.minkabu.jp/fund/"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept-Language": "ja-JP,ja;q=0.9",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Fund Data Structure

    struct FundQuote {
        let code: String           // 8桁コード (e.g., 0331418A)
        let name: String           // ファンド名
        let nav: Double            // 基準価額 (Net Asset Value)
        let navChange: Double      // 前日比
        let navChangePercent: Double // 前日比%
        let navDate: Date?         // 基準日
        let currency: String       // 通貨 (JPY)

        // Additional fund info
        let totalNetAssets: Double? // 純資産総額（百万円）
        let category: String?       // カテゴリ
        let managementCompany: String? // 運用会社
    }

    // MARK: - Fetch Fund Quote

    /// 从Yahoo Finance Japan获取投信数据
    func fetchFundQuote(code: String) async throws -> FundQuote {
        // Clean the code (remove any suffix)
        let cleanCode = code.replacingOccurrences(of: ".T", with: "")
            .replacingOccurrences(of: ".JP", with: "")
            .uppercased()

        // Try Yahoo Finance Japan first
        if let quote = try? await fetchFromYahooJapan(code: cleanCode) {
            return quote
        }

        // Fallback to Minkabu
        if let quote = try? await fetchFromMinkabu(code: cleanCode) {
            return quote
        }

        throw JapanFundError.fundNotFound
    }

    /// 批量获取多个投信数据
    func fetchFundQuotes(codes: [String]) async throws -> [FundQuote] {
        var results: [FundQuote] = []

        for code in codes {
            if let quote = try? await fetchFundQuote(code: code) {
                results.append(quote)
            }
        }

        return results
    }

    // MARK: - Yahoo Finance Japan

    private func fetchFromYahooJapan(code: String) async throws -> FundQuote {
        let urlString = "\(baseURL)\(code)"
        guard let url = URL(string: urlString) else {
            throw JapanFundError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw JapanFundError.httpError
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw JapanFundError.decodingError
        }

        return try parseYahooJapanHTML(html: html, code: code)
    }

    private func parseYahooJapanHTML(html: String, code: String) throws -> FundQuote {
        // Extract fund name - try multiple patterns
        let name = extractPattern(from: html, pattern: #"<h1[^>]*>([^<]+)</h1>"#) ??
                   extractPattern(from: html, pattern: #"FullName[^>]*>([^<]+)<"#) ??
                   extractPattern(from: html, pattern: #"class="[^"]*name[^"]*"[^>]*>([^<]+)<"#) ??
                   "投資信託 \(code)"

        // Extract NAV (基準価額) - Yahoo Japan uses StyledNumber__value class
        var nav: Double = 0

        // Primary pattern: StyledNumber__value__XXX">34,047<
        if let navStr = extractPattern(from: html, pattern: #"StyledNumber__value[^>]*>([0-9,]+)<"#) {
            nav = parseJapaneseNumber(navStr)
        }
        // Fallback: PriceBoard__price followed by value
        else if let navStr = extractPattern(from: html, pattern: #"PriceBoard__price[^>]*>[^0-9]*([0-9,]+)"#) {
            nav = parseJapaneseNumber(navStr)
        }
        // Legacy pattern
        else if let navStr = extractPattern(from: html, pattern: #"基準価額[^0-9]*([0-9,]+)"#) {
            nav = parseJapaneseNumber(navStr)
        }

        // Extract change - look for priceChange section
        var navChange: Double = 0
        var navChangePercent: Double = 0

        // Pattern for change value: item--blue or item--red followed by sign and number
        if let changeStr = extractPattern(from: html, pattern: #"item--(blue|red)[^>]*>[^0-9+-]*([+-]?[0-9,]+)"#) {
            navChange = parseJapaneseNumber(changeStr)
        } else if let changeStr = extractPattern(from: html, pattern: #"前日比[^0-9+-]*([+-]?[0-9,]+)"#) {
            navChange = parseJapaneseNumber(changeStr)
        }

        // Pattern for percent: (±X.XX%)
        if let percentStr = extractPattern(from: html, pattern: #"\(([+-]?[0-9.]+)%\)"#) {
            navChangePercent = Double(percentStr) ?? 0
        }

        // Extract total net assets (純資産)
        var totalNetAssets: Double? = nil
        if let assetsStr = extractPattern(from: html, pattern: #"純資産[^0-9]*([0-9,]+)"#) {
            totalNetAssets = parseJapaneseNumber(assetsStr)
        }

        // Extract category
        let category = extractPattern(from: html, pattern: #"カテゴリ[^>]*>([^<]+)<"#)

        // Extract management company
        let managementCompany = extractPattern(from: html, pattern: #"運用会社[^>]*>([^<]+)<"#)

        guard nav > 100 else {  // NAV should be at least 100 yen for mutual funds
            throw JapanFundError.parseError
        }

        return FundQuote(
            code: code,
            name: cleanHTMLText(name),
            nav: nav,
            navChange: navChange,
            navChangePercent: navChangePercent,
            navDate: Date(),
            currency: "JPY",
            totalNetAssets: totalNetAssets,
            category: category.map { cleanHTMLText($0) },
            managementCompany: managementCompany.map { cleanHTMLText($0) }
        )
    }

    // MARK: - Minkabu Backup

    private func fetchFromMinkabu(code: String) async throws -> FundQuote {
        let urlString = "\(minkabuURL)\(code)"
        guard let url = URL(string: urlString) else {
            throw JapanFundError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw JapanFundError.httpError
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw JapanFundError.decodingError
        }

        return try parseMinkabuHTML(html: html, code: code)
    }

    private func parseMinkabuHTML(html: String, code: String) throws -> FundQuote {
        // Extract fund name
        let name = extractPattern(from: html, pattern: #"<h1[^>]*>([^<]+)</h1>"#) ??
                   extractPattern(from: html, pattern: #"fund-name[^>]*>([^<]+)<"#) ??
                   extractPattern(from: html, pattern: #"<title>([^<|]+)"#) ??
                   "投資信託 \(code)"

        // Extract NAV - look for large numbers (5 digits with comma)
        var nav: Double = 0

        // Find all numbers in format XX,XXX (typical NAV format)
        let numberPattern = #"([0-9]{1,2},[0-9]{3})"#
        if let regex = try? NSRegularExpression(pattern: numberPattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)

            // Take the first match that looks like a NAV (10,000 - 99,999 range)
            for match in matches {
                if let matchRange = Range(match.range(at: 1), in: html) {
                    let navStr = String(html[matchRange])
                    let parsedNav = parseJapaneseNumber(navStr)
                    if parsedNav >= 1000 && parsedNav <= 100000 {
                        nav = parsedNav
                        break
                    }
                }
            }
        }

        // Fallback: Legacy patterns
        if nav == 0 {
            if let navStr = extractPattern(from: html, pattern: #"基準価額[^0-9]*([0-9,]+)"#) {
                nav = parseJapaneseNumber(navStr)
            }
        }

        // Extract change
        var navChange: Double = 0
        var navChangePercent: Double = 0

        if let changeStr = extractPattern(from: html, pattern: #"([+-][0-9,]+)\s*円"#) {
            navChange = parseJapaneseNumber(changeStr)
        }

        if let percentStr = extractPattern(from: html, pattern: #"([+-]?[0-9.]+)\s*%"#) {
            navChangePercent = Double(percentStr) ?? 0
        }

        guard nav > 100 else {
            throw JapanFundError.parseError
        }

        return FundQuote(
            code: code,
            name: cleanHTMLText(name),
            nav: nav,
            navChange: navChange,
            navChangePercent: navChangePercent,
            navDate: Date(),
            currency: "JPY",
            totalNetAssets: nil,
            category: nil,
            managementCompany: nil
        )
    }

    // MARK: - Search Funds

    struct FundSearchResult {
        let code: String
        let name: String
        let category: String?
        let managementCompany: String?
    }

    /// 常用投信列表 (预设的热门投信)
    static let popularFunds: [FundSearchResult] = [
        FundSearchResult(code: "0331418A", name: "eMAXIS Slim 米国株式(S&P500)", category: "米国株式", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "03311187", name: "eMAXIS Slim 全世界株式(オール・カントリー)", category: "全世界株式", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "03311172", name: "eMAXIS Slim 先進国株式インデックス", category: "先進国株式", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "0331117C", name: "eMAXIS Slim 国内株式(TOPIX)", category: "日本株式", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "0331418B", name: "eMAXIS Slim 新興国株式インデックス", category: "新興国株式", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "9C311125", name: "SBI・V・S&P500インデックス・ファンド", category: "米国株式", managementCompany: "SBIアセット"),
        FundSearchResult(code: "9C31121A", name: "SBI・V・全米株式インデックス・ファンド", category: "米国株式", managementCompany: "SBIアセット"),
        FundSearchResult(code: "89311199", name: "楽天・全米株式インデックス・ファンド", category: "米国株式", managementCompany: "楽天投信投資顧問"),
        FundSearchResult(code: "9I311179", name: "ニッセイ外国株式インデックスファンド", category: "先進国株式", managementCompany: "ニッセイアセット"),
        FundSearchResult(code: "29311164", name: "たわらノーロード 先進国株式", category: "先進国株式", managementCompany: "アセマネOne"),
    ]

    /// 搜索投信 (本地匹配 + 在线搜索)
    func searchFunds(query: String) async -> [FundSearchResult] {
        let lowercaseQuery = query.lowercased()

        // First, search in popular funds
        var results = Self.popularFunds.filter { fund in
            fund.code.lowercased().contains(lowercaseQuery) ||
            fund.name.lowercased().contains(lowercaseQuery) ||
            (fund.category?.lowercased().contains(lowercaseQuery) ?? false)
        }

        // If query looks like a fund code (8 alphanumeric), try fetching it directly
        if query.count == 8, query.allSatisfy({ $0.isLetter || $0.isNumber }) {
            if let quote = try? await fetchFundQuote(code: query) {
                let directResult = FundSearchResult(
                    code: quote.code,
                    name: quote.name,
                    category: quote.category,
                    managementCompany: quote.managementCompany
                )
                // Add to front if not already present
                if !results.contains(where: { $0.code == directResult.code }) {
                    results.insert(directResult, at: 0)
                }
            }
        }

        return results
    }

    // MARK: - Helpers

    private func extractPattern(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1 else {
            return nil
        }

        guard let matchRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[matchRange])
    }

    private func parseJapaneseNumber(_ str: String) -> Double {
        let cleaned = str.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "円", with: "")
            .replacingOccurrences(of: "+", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0
    }

    private func cleanHTMLText(_ text: String) -> String {
        var result = text
        // Remove HTML entities
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " "
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        // Trim whitespace
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum JapanFundError: LocalizedError {
    case invalidURL
    case httpError
    case decodingError
    case parseError
    case fundNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:    return "Invalid URL"
        case .httpError:     return "Network error"
        case .decodingError: return "Decoding error"
        case .parseError:    return "Failed to parse fund data"
        case .fundNotFound:  return "Fund not found"
        }
    }
}

// MARK: - Convert to MarketDataService.QuoteData

extension JapanFundService.FundQuote {
    /// 转换为通用QuoteData格式，便于统一处理
    func toQuoteData() -> MarketDataService.QuoteData {
        return MarketDataService.QuoteData(
            symbol: code,
            shortName: name,
            longName: name,
            regularMarketPrice: nav,
            regularMarketChange: navChange,
            regularMarketChangePercent: navChangePercent,
            regularMarketPreviousClose: nav - navChange,
            currency: currency,
            marketState: "CLOSED", // 投信没有实时交易
            preMarketPrice: nil,
            preMarketChange: nil,
            preMarketChangePercent: nil,
            postMarketPrice: nil,
            postMarketChange: nil,
            postMarketChangePercent: nil,
            regularMarketOpen: nil,
            regularMarketDayHigh: nil,
            regularMarketDayLow: nil,
            regularMarketVolume: nil,
            marketCap: totalNetAssets.map { $0 * 1_000_000 }, // 百万円 -> 円
            trailingPE: nil,
            fiftyTwoWeekHigh: nil,
            fiftyTwoWeekLow: nil,
            dividendYield: nil,
            epsTrailingTwelveMonths: nil
        )
    }
}
