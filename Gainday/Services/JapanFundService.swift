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

    /// 批量获取多个投信数据（并发请求）
    func fetchFundQuotes(codes: [String]) async throws -> [FundQuote] {
        await withTaskGroup(of: FundQuote?.self) { group in
            for code in codes {
                group.addTask { [weak self] in
                    try? await self?.fetchFundQuote(code: code)
                }
            }
            var results: [FundQuote] = []
            for await quote in group {
                if let quote { results.append(quote) }
            }
            return results
        }
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

    /// 投信データベース（主要投信を網羅）
    static let popularFunds: [FundSearchResult] = [
        // MARK: eMAXIS Slim (三菱UFJアセット) — 最受欢迎的低成本指数基金
        FundSearchResult(code: "0331418A", name: "eMAXIS Slim 米国株式(S&P500)", category: "米国株式", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "03311187", name: "eMAXIS Slim 全世界株式(オール・カントリー)", category: "全世界株式", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "03316183", name: "eMAXIS Slim 全世界株式(除く日本)", category: "全世界株式", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "03311172", name: "eMAXIS Slim 先進国株式インデックス", category: "先進国株式", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "0331117C", name: "eMAXIS Slim 国内株式(TOPIX)", category: "日本株式", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "0331117A", name: "eMAXIS Slim 国内株式(日経平均)", category: "日本株式", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "0331418B", name: "eMAXIS Slim 新興国株式インデックス", category: "新興国株式", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "03311179", name: "eMAXIS Slim バランス(8資産均等型)", category: "バランス", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "03311174", name: "eMAXIS Slim 先進国債券インデックス", category: "先進国債券", managementCompany: "三菱UFJアセット"),
        FundSearchResult(code: "0331118A", name: "eMAXIS Slim 国内債券インデックス", category: "日本債券", managementCompany: "三菱UFJアセット"),

        // MARK: iFree / iFreeNEXT (大和アセット)
        FundSearchResult(code: "04311181", name: "iFreeNEXT FANG+インデックス", category: "米国株式", managementCompany: "大和アセット"),
        FundSearchResult(code: "04317188", name: "iFreeNEXT NASDAQ100インデックス", category: "米国株式", managementCompany: "大和アセット"),
        FundSearchResult(code: "04314233", name: "iFreeNEXT インド株インデックス", category: "インド株式", managementCompany: "大和アセット"),
        FundSearchResult(code: "04311172", name: "iFree S&P500インデックス", category: "米国株式", managementCompany: "大和アセット"),
        FundSearchResult(code: "04311176", name: "iFree 日経225インデックス", category: "日本株式", managementCompany: "大和アセット"),
        FundSearchResult(code: "04311174", name: "iFree TOPIXインデックス", category: "日本株式", managementCompany: "大和アセット"),
        FundSearchResult(code: "04311179", name: "iFree 外国株式インデックス(為替ヘッジなし)", category: "先進国株式", managementCompany: "大和アセット"),

        // MARK: SBI・V (SBIアセット)
        FundSearchResult(code: "9C311125", name: "SBI・V・S&P500インデックス・ファンド", category: "米国株式", managementCompany: "SBIアセット"),
        FundSearchResult(code: "9C31121A", name: "SBI・V・全米株式インデックス・ファンド", category: "米国株式", managementCompany: "SBIアセット"),
        FundSearchResult(code: "9C311226", name: "SBI・V・全世界株式インデックス・ファンド", category: "全世界株式", managementCompany: "SBIアセット"),
        FundSearchResult(code: "9C311217", name: "SBI・V・先進国株式インデックス・ファンド", category: "先進国株式", managementCompany: "SBIアセット"),

        // MARK: 楽天 (楽天投信投資顧問)
        FundSearchResult(code: "89311199", name: "楽天・全米株式インデックス・ファンド(楽天VTI)", category: "米国株式", managementCompany: "楽天投信投資顧問"),
        FundSearchResult(code: "8931119A", name: "楽天・全世界株式インデックス・ファンド(楽天VT)", category: "全世界株式", managementCompany: "楽天投信投資顧問"),
        FundSearchResult(code: "89311207", name: "楽天・S&P500インデックス・ファンド", category: "米国株式", managementCompany: "楽天投信投資顧問"),
        FundSearchResult(code: "9I31123A", name: "楽天・プラス・オールカントリー株式インデックス・ファンド", category: "全世界株式", managementCompany: "楽天投信投資顧問"),
        FundSearchResult(code: "9I31223A", name: "楽天・プラス・S&P500インデックス・ファンド", category: "米国株式", managementCompany: "楽天投信投資顧問"),
        FundSearchResult(code: "9I314241", name: "楽天・プラス・NASDAQ-100インデックス・ファンド", category: "米国株式", managementCompany: "楽天投信投資顧問"),

        // MARK: ニッセイ (ニッセイアセット)
        FundSearchResult(code: "9I311179", name: "ニッセイ外国株式インデックスファンド", category: "先進国株式", managementCompany: "ニッセイアセット"),
        FundSearchResult(code: "9I31117A", name: "ニッセイTOPIXインデックスファンド", category: "日本株式", managementCompany: "ニッセイアセット"),
        FundSearchResult(code: "9I311186", name: "ニッセイ日経225インデックスファンド", category: "日本株式", managementCompany: "ニッセイアセット"),
        FundSearchResult(code: "9I311191", name: "ニッセイ・インデックスバランスファンド(4資産均等型)", category: "バランス", managementCompany: "ニッセイアセット"),

        // MARK: たわらノーロード (アセマネOne)
        FundSearchResult(code: "29311164", name: "たわらノーロード 先進国株式", category: "先進国株式", managementCompany: "アセマネOne"),
        FundSearchResult(code: "29311165", name: "たわらノーロード 日経225", category: "日本株式", managementCompany: "アセマネOne"),
        FundSearchResult(code: "29311166", name: "たわらノーロード TOPIX", category: "日本株式", managementCompany: "アセマネOne"),
        FundSearchResult(code: "29311168", name: "たわらノーロード 全世界株式", category: "全世界株式", managementCompany: "アセマネOne"),
        FundSearchResult(code: "29311170", name: "たわらノーロード バランス(8資産均等型)", category: "バランス", managementCompany: "アセマネOne"),

        // MARK: はじめてのNISA (野村アセット)
        FundSearchResult(code: "01312237", name: "はじめてのNISA・全世界株式インデックス(オール・カントリー)", category: "全世界株式", managementCompany: "野村アセット"),
        FundSearchResult(code: "01311237", name: "はじめてのNISA・米国株式インデックス(S&P500)", category: "米国株式", managementCompany: "野村アセット"),
        FundSearchResult(code: "01313237", name: "はじめてのNISA・日本株式インデックス(日経225)", category: "日本株式", managementCompany: "野村アセット"),

        // MARK: 野村インデックスファンド (野村アセット)
        FundSearchResult(code: "01311159", name: "野村インデックスファンド・日経225", category: "日本株式", managementCompany: "野村アセット"),
        FundSearchResult(code: "01311157", name: "野村インデックスファンド・TOPIX", category: "日本株式", managementCompany: "野村アセット"),
        FundSearchResult(code: "01311163", name: "野村インデックスファンド・外国株式", category: "先進国株式", managementCompany: "野村アセット"),

        // MARK: Smart-i (りそなアセット)
        FundSearchResult(code: "53311119", name: "Smart-i 先進国株式インデックス", category: "先進国株式", managementCompany: "りそなアセット"),
        FundSearchResult(code: "53311120", name: "Smart-i TOPIXインデックス", category: "日本株式", managementCompany: "りそなアセット"),
        FundSearchResult(code: "53311123", name: "Smart-i 8資産バランス(安定成長型)", category: "バランス", managementCompany: "りそなアセット"),

        // MARK: Tracers (日興アセット)
        FundSearchResult(code: "02312234", name: "Tracers MSCIオール・カントリー・インデックス(全世界株式)", category: "全世界株式", managementCompany: "日興アセット"),
        FundSearchResult(code: "0231122A", name: "Tracers S&P500配当貴族インデックス(米国株式)", category: "米国株式", managementCompany: "日興アセット"),

        // MARK: ひふみ (レオス・キャピタルワークス)
        FundSearchResult(code: "96311073", name: "ひふみプラス", category: "日本株式", managementCompany: "レオス・キャピタルワークス"),
        FundSearchResult(code: "9C31119C", name: "ひふみワールド+", category: "全世界株式", managementCompany: "レオス・キャピタルワークス"),

        // MARK: セゾン
        FundSearchResult(code: "47311074", name: "セゾン・グローバルバランスファンド", category: "バランス", managementCompany: "セゾン投信"),
        FundSearchResult(code: "47311081", name: "セゾン資産形成の達人ファンド", category: "全世界株式", managementCompany: "セゾン投信"),

        // MARK: 三井住友 DC
        FundSearchResult(code: "79311144", name: "三井住友・DCつみたてNISA・日本株インデックスファンド", category: "日本株式", managementCompany: "三井住友DSアセット"),
        FundSearchResult(code: "79311148", name: "三井住友・DCつみたてNISA・全海外株インデックスファンド", category: "全世界株式", managementCompany: "三井住友DSアセット"),

        // MARK: SOMPO
        FundSearchResult(code: "4531121C", name: "SOMPO123 先進国株式", category: "先進国株式", managementCompany: "SOMPOアセット"),

        // MARK: コモンズ
        FundSearchResult(code: "6431117C", name: "コモンズ30ファンド", category: "日本株式", managementCompany: "コモンズ投信"),

        // MARK: 年金積立 (日興アセット)
        FundSearchResult(code: "0231Q01A", name: "年金積立 Jグロース", category: "日本株式", managementCompany: "日興アセット"),
    ]

    /// 搜索投信（本地 + 在线并行搜索）
    func searchFunds(query: String) async -> [FundSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        let lowercaseQuery = trimmed.lowercased()

        // 本地匹配
        let localResults = Self.popularFunds.filter { fund in
            fund.code.lowercased().contains(lowercaseQuery) ||
            fund.name.lowercased().contains(lowercaseQuery) ||
            (fund.category?.lowercased().contains(lowercaseQuery) ?? false) ||
            (fund.managementCompany?.lowercased().contains(lowercaseQuery) ?? false)
        }

        // 代码直接获取 + 在线搜索并行执行
        async let directFetch: FundSearchResult? = {
            if trimmed.count >= 7 && trimmed.count <= 8,
               trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) {
                if let quote = try? await self.fetchFundQuote(code: trimmed) {
                    return FundSearchResult(
                        code: quote.code,
                        name: quote.name,
                        category: quote.category,
                        managementCompany: quote.managementCompany
                    )
                }
            }
            return nil
        }()

        async let onlineResults = searchFundsOnline(query: trimmed)

        // 合并结果：去重
        var seen = Set<String>()
        var results: [FundSearchResult] = []

        // 代码直接获取优先
        if let direct = await directFetch, !seen.contains(direct.code) {
            seen.insert(direct.code)
            results.append(direct)
        }

        // 本地结果
        for r in localResults where !seen.contains(r.code) {
            seen.insert(r.code)
            results.append(r)
        }

        // 在线结果
        for r in await onlineResults where !seen.contains(r.code) {
            seen.insert(r.code)
            results.append(r)
        }

        return results
    }

    // MARK: - Online Search

    /// 使用 Yahoo Finance suggest API 搜索投信（返回 JSON，稳定可靠）
    private func searchFundsOnline(query: String) async -> [FundSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        // Yahoo Finance global search API — 支持日本投信
        let urlString = "https://query2.finance.yahoo.com/v1/finance/search?q=\(encoded)&quotesCount=20&newsCount=0&listsCount=0&enableFuzzyQuery=false"
        guard let url = URL(string: urlString) else { return [] }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }

            return parseYahooSearchJSON(data: data)
        } catch {
            // fallback: Minkabu 搜索
            return await searchFundsViaMinkabu(query: query)
        }
    }

    /// 解析 Yahoo Finance search JSON 响应
    private func parseYahooSearchJSON(data: Data) -> [FundSearchResult] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let quotes = json["quotes"] as? [[String: Any]] else { return [] }

        var results: [FundSearchResult] = []
        for quote in quotes {
            guard let symbol = quote["symbol"] as? String,
                  let name = quote["longname"] as? String ?? quote["shortname"] as? String else { continue }

            // 过滤出投信代码（7-8位英数字，无后缀）
            let code = symbol.replacingOccurrences(of: ".T", with: "")
            guard code.count >= 7 && code.count <= 8,
                  code.allSatisfy({ $0.isLetter || $0.isNumber }) else { continue }

            let category = quote["industry"] as? String
            results.append(FundSearchResult(
                code: code,
                name: cleanHTMLText(name),
                category: category,
                managementCompany: nil
            ))
        }
        return results
    }

    /// Minkabu 在线搜索（备用方案）
    private func searchFundsViaMinkabu(query: String) async -> [FundSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://itf.minkabu.jp/search?q=\(encoded)"
        guard let url = URL(string: urlString) else { return [] }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else { return [] }

            return parseMinkabuSearchResults(html: html)
        } catch {
            return []
        }
    }

    /// 解析 Minkabu 搜索结果 HTML
    private func parseMinkabuSearchResults(html: String) -> [FundSearchResult] {
        var results: [FundSearchResult] = []

        // Minkabu 的基金链接格式: /fund/XXXXXXXX
        guard let regex = try? NSRegularExpression(
            pattern: #"href="/fund/([0-9A-Za-z]{7,8})"[^>]*>([^<]+)<"#,
            options: []
        ) else { return [] }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)

        for match in matches.prefix(15) {
            guard match.numberOfRanges >= 3,
                  let codeRange = Range(match.range(at: 1), in: html),
                  let nameRange = Range(match.range(at: 2), in: html) else { continue }

            let code = String(html[codeRange])
            let name = cleanHTMLText(String(html[nameRange]))
            guard !name.isEmpty else { continue }

            results.append(FundSearchResult(
                code: code,
                name: name,
                category: nil,
                managementCompany: nil
            ))
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

        // Return the last capture group (fixes multi-group patterns like "item--(blue|red)...(number)")
        let lastGroupIndex = match.numberOfRanges - 1
        guard let matchRange = Range(match.range(at: lastGroupIndex), in: text) else {
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
