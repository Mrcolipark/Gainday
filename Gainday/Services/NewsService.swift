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
        var allNews: [NewsItem] = []

        // Try Yahoo Finance RSS (has media:content images)
        let yahooURL = "https://finance.yahoo.com/news/rssindex"
        if let yahooNews = try? await parseRSS(url: yahooURL, source: "Yahoo Finance") {
            allNews.append(contentsOf: yahooNews)
        }

        // Try BBC Business RSS as backup (has media:thumbnail images)
        let bbcURL = "https://feeds.bbci.co.uk/news/business/rss.xml"
        if let bbcNews = try? await parseRSS(url: bbcURL, source: "BBC") {
            allNews.append(contentsOf: bbcNews)
        }

        // Sort by date and return top items
        return allNews
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
            .prefix(15)
            .map { $0 }
    }

    // MARK: - CN News (新浪财经)

    private func fetchCNNews() async throws -> [NewsItem] {
        var allNews: [NewsItem] = []

        // 新浪财经 API (has images in img/images fields)
        let sinaURL = "https://feed.mix.sina.com.cn/api/roll/get?pageid=153&lid=2516&k=&num=20&page=1"
        if let sinaNews = try? await fetchSinaNews(url: sinaURL) {
            allNews.append(contentsOf: sinaNews)
        }

        return allNews
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
            .prefix(15)
            .map { $0 }
    }

    // MARK: - HK News (繁體中文 Traditional Chinese sources)

    private func fetchHKNews() async throws -> [NewsItem] {
        var allNews: [NewsItem] = []

        // Yahoo Finance 香港版 RSS (繁體中文，來源 AASTOCKS，有圖片)
        let yahooHKURL = "https://hk.finance.yahoo.com/rss/topstories"
        if let yahooNews = try? await parseRSS(url: yahooHKURL, source: "Yahoo 財經") {
            allNews.append(contentsOf: yahooNews)
        }

        // SCMP Global Economy (英文，有港股及財經內容，有圖片)
        let scmpEconURL = "https://www.scmp.com/rss/12/feed"
        if let scmpNews = try? await parseRSS(url: scmpEconURL, source: "SCMP") {
            allNews.append(contentsOf: scmpNews)
        }

        // 如果數據不足，添加 SCMP Hong Kong 新聞
        if allNews.count < 10 {
            let scmpHKURL = "https://www.scmp.com/rss/2/feed"
            if let scmpHKNews = try? await parseRSS(url: scmpHKURL, source: "SCMP HK") {
                allNews.append(contentsOf: scmpHKNews)
            }
        }

        return allNews
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
            .prefix(15)
            .map { $0 }
    }

    // MARK: - JP News (東洋経済オンライン)

    private func fetchJPNews() async throws -> [NewsItem] {
        var allNews: [NewsItem] = []

        // 東洋経済オンライン RSS (日本語財経ニュース、画像あり)
        let toyokeizaiURL = "https://toyokeizai.net/list/feed/rss"
        if let toyokeizaiNews = try? await parseRSS(url: toyokeizaiURL, source: "東洋経済") {
            allNews.append(contentsOf: toyokeizaiNews)
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
        let items = parser.parse(data: data)

        #if DEBUG
        print("[NewsService] \(source): \(items.count) items, \(items.filter { $0.imageURL != nil }.count) with images")
        #endif

        return items
    }

    // MARK: - Sina News API

    private func fetchSinaNews(url: String, sourceOverride: String? = nil) async throws -> [NewsItem] {
        guard let apiURL = URL(string: url) else { return [] }

        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: request)

        // Parse Sina JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let dataArray = result["data"] as? [[String: Any]] else {
            #if DEBUG
            print("[NewsService] Sina API failed to parse: \(sourceOverride ?? "unknown")")
            #endif
            return []
        }

        #if DEBUG
        let imageCount = dataArray.filter { item in
            (item["img"] as? [String: Any])?["u"] != nil ||
            (item["images"] as? [[String: Any]])?.first?["u"] != nil
        }.count
        print("[NewsService] Sina \(sourceOverride ?? "财经"): \(dataArray.count) items, \(imageCount) with images")
        #endif

        return dataArray.compactMap { item -> NewsItem? in
            guard let title = item["title"] as? String,
                  let url = item["url"] as? String else { return nil }

            let intro = item["intro"] as? String ?? ""
            let ctime = item["ctime"] as? String ?? ""

            // Extract image URL from img or images field
            var imageURL: String? = nil

            // Try img field first (single image object)
            if let img = item["img"] as? [String: Any],
               let imgUrl = img["u"] as? String,
               !imgUrl.isEmpty {
                imageURL = imgUrl
            }

            // If no img, try images array (first image)
            if imageURL == nil,
               let images = item["images"] as? [[String: Any]],
               let firstImage = images.first,
               let imgUrl = firstImage["u"] as? String,
               !imgUrl.isEmpty {
                imageURL = imgUrl
            }

            // Parse date - ctime is Unix timestamp string
            var date: Date? = nil
            if let timestamp = Double(ctime) {
                date = Date(timeIntervalSince1970: timestamp)
            }

            return NewsItem(
                id: url,
                title: title,
                description: intro,
                source: sourceOverride ?? "新浪财经",
                url: url,
                publishedAt: date,
                imageURL: imageURL
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
    private var currentImageURL = ""
    private var isInItem = false

    init(source: String) {
        self.source = source
    }

    func parse(data: Data) -> [NewsService.NewsItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldReportNamespacePrefixes = true
        parser.shouldProcessNamespaces = false  // Keep prefixes in element names
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        // elementName already includes prefix when shouldProcessNamespaces = false
        let name = elementName
        currentElement = name


        if name == "item" || name == "entry" {
            isInItem = true
            currentTitle = ""
            currentDescription = ""
            currentLink = ""
            currentPubDate = ""
            currentImageURL = ""
        }

        // Handle Atom feed links
        if name == "link" && isInItem {
            if let href = attributeDict["href"] {
                currentLink = href
            }
        }

        // Extract image from media:content, media:thumbnail, enclosure, or any element with image URL
        if isInItem && currentImageURL.isEmpty {
            // Try both "url" and "URL" (case-insensitive lookup)
            let url = attributeDict["url"] ?? attributeDict["URL"] ?? attributeDict.first { $0.key.lowercased() == "url" }?.value
            if let url = url, !url.isEmpty {
                // Check if this is a media/image-related element by name
                let lowercaseName = name.lowercased()
                let isMediaElement = lowercaseName == "media:content" ||
                                     lowercaseName == "media:thumbnail" ||
                                     lowercaseName.contains("thumbnail") ||
                                     lowercaseName.contains("image") ||
                                     lowercaseName == "enclosure"

                // Or check if the URL looks like an image
                let looksLikeImage = url.contains("yimg.com") ||
                                     url.contains("zenfs.com") ||
                                     url.contains("bbci") ||
                                     url.contains("ichef") ||
                                     url.contains("i-scmp.com") ||
                                     url.contains("scmp.com") ||
                                     url.contains(".jpg") ||
                                     url.contains(".jpeg") ||
                                     url.contains(".png") ||
                                     url.contains(".gif") ||
                                     url.contains(".webp") ||
                                     url.contains("image") ||
                                     url.contains("creatr") ||
                                     url.contains("photo")

                // For enclosure, also check the type attribute
                let enclosureType = attributeDict["type"] ?? ""
                let isImageEnclosure = name.lowercased() == "enclosure" &&
                                       (enclosureType.isEmpty || enclosureType.hasPrefix("image/"))

                if isMediaElement || looksLikeImage || isImageEnclosure {
                    currentImageURL = url
                }
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
        let name = qName ?? elementName
        if name == "item" || name == "entry" {
            isInItem = false

            // Try to extract image from description HTML if not found elsewhere
            var imageURL = currentImageURL
            if imageURL.isEmpty {
                imageURL = extractImageFromHTML(currentDescription)
            }

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
                    imageURL: imageURL.isEmpty ? nil : imageURL
                )
                items.append(item)
            }
        }
    }

    /// Extract image URL from HTML content (img src)
    private func extractImageFromHTML(_ html: String) -> String {
        // Pattern to match img src
        let pattern = #"<img[^>]+src=[\"']([^\"']+)[\"']"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(html.startIndex..., in: html)
            if let match = regex.firstMatch(in: html, range: range) {
                if let urlRange = Range(match.range(at: 1), in: html) {
                    return String(html[urlRange])
                }
            }
        }
        return ""
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
