import Foundation

/// 新闻服务 - 获取各市场财经新闻
actor NewsService {
    static let shared = NewsService()

    private init() {}

    // MARK: - News Item Model

    struct NewsItem: Identifiable, Sendable {
        let id: String
        let title: String
        let description: String
        let source: String
        let url: String
        let publishedAt: Date?
        let imageURL: String?

        var timeAgo: String {
            guard let date = publishedAt else { return "" }
            let interval = Date().timeIntervalSince(date)

            if interval < 3600 {
                let minutes = Int(interval / 60)
                return "\(max(1, minutes))m ago"
            } else if interval < 86400 {
                let hours = Int(interval / 3600)
                return "\(hours)h ago"
            } else {
                let days = Int(interval / 86400)
                return "\(days)d ago"
            }
        }
    }

    // MARK: - Fetch News by Market

    func fetchNews(market: String) async throws -> [NewsItem] {
        switch market {
        case "美股":
            return try await fetchUSNews()
        case "A股":
            return try await fetchCNNews()
        case "港股":
            return try await fetchHKNews()
        case "日股":
            return try await fetchJPNews()
        default:
            return try await fetchUSNews()
        }
    }

    // MARK: - US News (Yahoo Finance RSS)

    private func fetchUSNews() async throws -> [NewsItem] {
        // Yahoo Finance RSS
        let yahooURL = "https://finance.yahoo.com/news/rssindex"

        var allNews: [NewsItem] = []

        // Try Yahoo Finance RSS
        if let yahooNews = try? await parseRSS(url: yahooURL, source: "Yahoo Finance") {
            allNews.append(contentsOf: yahooNews)
        }

        // Try CNBC RSS as backup
        let cnbcURL = "https://www.cnbc.com/id/100003114/device/rss/rss.html"
        if let cnbcNews = try? await parseRSS(url: cnbcURL, source: "CNBC") {
            allNews.append(contentsOf: cnbcNews)
        }

        // Sort by date and return top items
        return allNews
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
            .prefix(15)
            .map { $0 }
    }

    // MARK: - CN News (新浪财经 RSS)

    private func fetchCNNews() async throws -> [NewsItem] {
        var allNews: [NewsItem] = []

        // 新浪财经 RSS
        let sinaURL = "https://feed.mix.sina.com.cn/api/roll/get?pageid=153&lid=2516&k=&num=20&page=1&callback="
        if let sinaNews = try? await fetchSinaNews(url: sinaURL) {
            allNews.append(contentsOf: sinaNews)
        }

        // 东方财富 API (简化版)
        let eastmoneyURL = "https://np-listapi.eastmoney.com/comm/web/getNewsByColumns?columns=100&pageSize=15&pageIndex=0"
        if let emNews = try? await fetchEastMoneyNews(url: eastmoneyURL) {
            allNews.append(contentsOf: emNews)
        }

        return allNews
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
            .prefix(15)
            .map { $0 }
    }

    // MARK: - HK News

    private func fetchHKNews() async throws -> [NewsItem] {
        var allNews: [NewsItem] = []

        // AAStocks RSS
        let aastocksURL = "http://www.aastocks.com/sc/resources/datafeed/rss/news/aafn-hk-all/0.xml"
        if let aastocksNews = try? await parseRSS(url: aastocksURL, source: "AAStocks") {
            allNews.append(contentsOf: aastocksNews)
        }

        // 如果没有数据，使用 Yahoo HK
        if allNews.isEmpty {
            let yahooHKURL = "https://hk.finance.yahoo.com/rss/topfinstories"
            if let yahooNews = try? await parseRSS(url: yahooHKURL, source: "Yahoo HK") {
                allNews.append(contentsOf: yahooNews)
            }
        }

        return allNews
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
            .prefix(15)
            .map { $0 }
    }

    // MARK: - JP News

    private func fetchJPNews() async throws -> [NewsItem] {
        var allNews: [NewsItem] = []

        // NHK 経済ニュース RSS (most reliable)
        let nhkURL = "https://www3.nhk.or.jp/rss/news/cat5.xml"
        if let nhkNews = try? await parseRSS(url: nhkURL, source: "NHK") {
            allNews.append(contentsOf: nhkNews)
        }

        // 日経新聞 RSS
        let nikkeiURL = "https://assets.wor.jp/rss/rdf/nikkei/news.rdf"
        if let nikkeiNews = try? await parseRSS(url: nikkeiURL, source: "日本経済新聞") {
            allNews.append(contentsOf: nikkeiNews)
        }

        return allNews
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
            .prefix(15)
            .map { $0 }
    }

    // MARK: - RSS Parser

    private func parseRSS(url: String, source: String) async throws -> [NewsItem] {
        guard let feedURL = URL(string: url) else { return [] }

        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)

        let parser = RSSParser(source: source)
        return parser.parse(data: data)
    }

    // MARK: - Sina News API

    private func fetchSinaNews(url: String) async throws -> [NewsItem] {
        guard let apiURL = URL(string: url) else { return [] }

        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)

        // Parse Sina JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let dataArray = result["data"] as? [[String: Any]] else {
            return []
        }

        return dataArray.compactMap { item -> NewsItem? in
            guard let title = item["title"] as? String,
                  let url = item["url"] as? String else { return nil }

            let intro = item["intro"] as? String ?? ""
            let ctime = item["ctime"] as? String ?? ""

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let date = dateFormatter.date(from: ctime)

            return NewsItem(
                id: url,
                title: title,
                description: intro,
                source: "新浪财经",
                url: url,
                publishedAt: date,
                imageURL: nil
            )
        }
    }

    // MARK: - EastMoney News API

    private func fetchEastMoneyNews(url: String) async throws -> [NewsItem] {
        guard let apiURL = URL(string: url) else { return [] }

        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let news = dataDict["news"] as? [[String: Any]] else {
            return []
        }

        return news.compactMap { item -> NewsItem? in
            guard let title = item["title"] as? String,
                  let url = item["url"] as? String else { return nil }

            let digest = item["digest"] as? String ?? ""
            let showtime = item["showtime"] as? String ?? ""

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let date = dateFormatter.date(from: showtime)

            return NewsItem(
                id: url,
                title: title,
                description: digest,
                source: "东方财富",
                url: url,
                publishedAt: date,
                imageURL: nil
            )
        }
    }
}

// MARK: - RSS Parser

private class RSSParser: NSObject, XMLParserDelegate {
    private let source: String
    private var items: [NewsService.NewsItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var isInItem = false

    init(source: String) {
        self.source = source
    }

    func parse(data: Data) -> [NewsService.NewsItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName

        if elementName == "item" || elementName == "entry" {
            isInItem = true
            currentTitle = ""
            currentDescription = ""
            currentLink = ""
            currentPubDate = ""
        }

        // Handle Atom feed links
        if elementName == "link" && isInItem {
            if let href = attributeDict["href"] {
                currentLink = href
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInItem else { return }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "description", "summary", "content":
            currentDescription += trimmed
        case "link":
            if currentLink.isEmpty {
                currentLink += trimmed
            }
        case "pubDate", "published", "updated", "dc:date":
            currentPubDate += trimmed
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            isInItem = false

            // Clean up HTML tags from description
            let cleanDescription = currentDescription
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse date
            let date = parseDate(currentPubDate)

            if !currentTitle.isEmpty && !currentLink.isEmpty {
                let item = NewsService.NewsItem(
                    id: currentLink,
                    title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: String(cleanDescription.prefix(200)),
                    source: source,
                    url: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                    publishedAt: date,
                    imageURL: nil
                )
                items.append(item)
            }
        }
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
}
