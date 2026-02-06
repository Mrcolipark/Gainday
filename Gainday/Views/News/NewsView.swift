import SwiftUI
import SafariServices

struct NewsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedMarket: NewsMarket = .us
    @State private var animateContent = false
    @State private var urlToOpen: URL?
    @State private var newsItems: [NewsService.NewsItem] = []
    @State private var isLoading = false
    @State private var lastLoadedMarket: NewsMarket?
    @State private var indices: [MarketDataService.QuoteData] = []

    // 蓝色主题色
    private let accentBlue = Color.blue

    enum NewsMarket: String, CaseIterable {
        case us = "美股"
        case cn = "A股"
        case hk = "港股"
        case jp = "日股"
    }

    var body: some View {
        AppNavigationWrapper(title: "News") {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // 品牌标题
                    brandHeader
                        .opacity(animateContent ? 1 : 0)

                    // 市场快讯 (迷你指数)
                    marketFlashSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 15)

                    // 新闻列表
                    newsListSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 10)

                    // 快速链接
                    quickLinksSection
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 10)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 30)
            }
            .background(AppColors.background)
            .refreshable {
                await loadData()
            }
            .task {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animateContent = true
                }
                await loadData()
            }
            .onChange(of: selectedMarket) { _, _ in
                Task { await loadNews() }
            }
            .sheet(item: $urlToOpen) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Load Data

    private func loadData() async {
        // 并行加载指数和新闻
        async let indicesTask: () = loadIndices()
        async let newsTask: () = loadNews()
        _ = await (indicesTask, newsTask)
    }

    private func loadIndices() async {
        do {
            let result = try await MarketDataService.shared.fetchMarketIndices()
            await MainActor.run { indices = result }
        } catch {
            print("[NewsView] Failed to load indices: \(error)")
        }
    }

    private func loadNews() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let items = try await NewsService.shared.fetchNews(market: selectedMarket.rawValue)
            await MainActor.run {
                newsItems = items
                lastLoadedMarket = selectedMarket
            }
        } catch {
            print("[NewsView] Failed to load news: \(error)")
        }
    }

    // MARK: - Brand Header

    private var brandHeader: some View {
        HStack {
            Text("GainDay")
                .font(.custom("Georgia-Bold", size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.profit, AppColors.profit.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("盈历")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()

            // 新闻状态
            HStack(spacing: 4) {
                Circle()
                    .fill(isLoading ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text(isLoading ? "加载中" : "实时")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(AppColors.elevatedSurface)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Market Flash Section

    private var marketFlashSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(accentBlue)
                Text("市场快讯")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal)

            // 使用 MarketsView 的自动轮播组件
            if indices.isEmpty {
                // Loading placeholder
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.elevatedSurface)
                                .frame(width: 40, height: 12)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.elevatedSurface)
                                .frame(width: 50, height: 14)
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
                .padding(.horizontal)
            } else {
                AutoScrollingTicker(indices: indices)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - News List Section

    private var newsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "newspaper.fill")
                    .foregroundStyle(accentBlue)
                Text("财经要闻")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal)

            // 市场选择器
            HStack(spacing: 0) {
                ForEach(NewsMarket.allCases, id: \.self) { market in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMarket = market
                        }
                    } label: {
                        Text(market.rawValue)
                            .font(.system(size: 13, weight: selectedMarket == market ? .semibold : .medium))
                            .foregroundStyle(selectedMarket == market ? .white : AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selectedMarket == market ? accentBlue : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.elevatedSurface)
            )
            .padding(.horizontal)

            // 头条新闻卡片
            if isLoading && newsItems.isEmpty {
                // Loading state
                FeaturedNewsCardLoading()
                    .padding(.horizontal)
            } else if let featured = newsItems.first {
                Button {
                    if let url = URL(string: featured.url) {
                        urlToOpen = url
                    }
                } label: {
                    FeaturedNewsCard(
                        title: featured.title,
                        subtitle: featured.description,
                        source: featured.source,
                        timeAgo: featured.timeAgo,
                        imageIcon: iconForSource(featured.source)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            } else {
                // Fallback placeholder
                let fallback = fallbackFeaturedNews(for: selectedMarket)
                Button {
                    if let url = URL(string: fallback.url) {
                        urlToOpen = url
                    }
                } label: {
                    FeaturedNewsCard(
                        title: fallback.title,
                        subtitle: fallback.subtitle,
                        source: fallback.source,
                        timeAgo: "",
                        imageIcon: fallback.icon
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }

            // 新闻列表
            VStack(spacing: 0) {
                if isLoading && newsItems.isEmpty {
                    // Loading shimmer
                    ForEach(0..<5, id: \.self) { _ in
                        NewsRowLoading()
                    }
                } else if newsItems.count > 1 {
                    // Real news from API
                    ForEach(Array(newsItems.dropFirst().prefix(10).enumerated()), id: \.element.id) { index, news in
                        Button {
                            if let url = URL(string: news.url) {
                                urlToOpen = url
                            }
                        } label: {
                            NewsRow(
                                title: news.title,
                                source: news.source,
                                timeAgo: news.timeAgo,
                                iconName: iconForSource(news.source),
                                accentColor: accentBlue
                            )
                        }
                        .buttonStyle(.plain)

                        if index < min(newsItems.count - 2, 9) {
                            Divider()
                                .padding(.horizontal)
                                .opacity(0.3)
                        }
                    }
                } else {
                    // Fallback static news
                    let fallbackNews = fallbackNewsItems(for: selectedMarket)
                    ForEach(Array(fallbackNews.enumerated()), id: \.offset) { index, news in
                        Button {
                            if let url = URL(string: news.url) {
                                urlToOpen = url
                            }
                        } label: {
                            NewsRow(
                                title: news.title,
                                source: news.source,
                                timeAgo: "",
                                iconName: news.icon,
                                accentColor: accentBlue
                            )
                        }
                        .buttonStyle(.plain)

                        if index < fallbackNews.count - 1 {
                            Divider()
                                .padding(.horizontal)
                                .opacity(0.3)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick Links Section

    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .foregroundStyle(accentBlue)
                Text("更多来源")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    let links = quickLinks(for: selectedMarket)
                    ForEach(links, id: \.name) { link in
                        Button {
                            if let url = URL(string: link.url) {
                                urlToOpen = url
                            }
                        } label: {
                            QuickLinkCard(name: link.name, icon: link.icon, color: accentBlue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helper Functions

    private func iconForSource(_ source: String) -> String {
        let sourceIcons: [String: String] = [
            "Yahoo Finance": "chart.line.uptrend.xyaxis",
            "Yahoo!ファイナンス": "chart.line.uptrend.xyaxis",
            "Yahoo HK": "chart.line.uptrend.xyaxis",
            "Bloomberg": "building.2.fill",
            "Bloomberg Japan": "building.2.fill",
            "Reuters": "globe",
            "ロイター": "globe",
            "CNBC": "tv.fill",
            "新浪财经": "s.circle.fill",
            "东方财富": "chart.bar.fill",
            "财联社": "newspaper.fill",
            "AAStocks": "chart.xyaxis.line",
            "日本経済新聞": "n.circle.fill",
            "NHK": "tv.fill",
            "香港经济日报": "dollarsign.circle.fill"
        ]
        return sourceIcons[source] ?? "newspaper.fill"
    }

    // MARK: - Fallback Data

    private func fallbackFeaturedNews(for market: NewsMarket) -> (title: String, subtitle: String, source: String, icon: String, url: String) {
        switch market {
        case .us:
            return (
                "Markets Today: Fed signals steady rates",
                "Wall Street awaits inflation data as Treasury yields stabilize",
                "Yahoo Finance",
                "chart.line.uptrend.xyaxis",
                "https://finance.yahoo.com"
            )
        case .cn:
            return (
                "A股三大指数集体收涨",
                "北向资金净买入超50亿，科技股领涨两市",
                "东方财富",
                "chart.bar.fill",
                "https://www.eastmoney.com"
            )
        case .hk:
            return (
                "港股恒指高开 科技股造好",
                "腾讯、阿里领涨蓝筹，南向资金持续流入",
                "香港经济日报",
                "building.2.fill",
                "https://invest.hket.com"
            )
        case .jp:
            return (
                "日経平均、続伸で始まる",
                "円安進行で輸出関連株に買い、半導体株も堅調",
                "日本経済新聞",
                "yensign.circle.fill",
                "https://www.nikkei.com/markets"
            )
        }
    }

    private func fallbackNewsItems(for market: NewsMarket) -> [(title: String, source: String, icon: String, url: String)] {
        switch market {
        case .us:
            return [
                ("NVIDIA beats Q4 estimates on strong AI demand", "Reuters", "cpu.fill", "https://www.reuters.com/technology"),
                ("Tesla shares rise on delivery outlook", "Bloomberg", "car.fill", "https://www.bloomberg.com/quote/TSLA:US"),
                ("Apple Vision Pro sales exceed expectations", "CNBC", "visionpro.fill", "https://www.cnbc.com/technology"),
                ("Bitcoin rallies past key resistance level", "Yahoo Finance", "bitcoinsign.circle.fill", "https://finance.yahoo.com"),
                ("Amazon AWS growth accelerates", "CNBC", "cloud.fill", "https://www.cnbc.com/quotes/AMZN"),
            ]
        case .cn:
            return [
                ("宁德时代发布新一代电池技术", "财联社", "battery.100.bolt", "https://www.cls.cn"),
                ("比亚迪出口量创历史新高", "新浪财经", "car.fill", "https://finance.sina.com.cn"),
                ("中芯国际产能利用率回升", "东方财富", "cpu.fill", "https://www.eastmoney.com"),
                ("茅台一季度业绩预增", "东方财富", "wineglass.fill", "https://www.eastmoney.com"),
                ("券商板块午后拉升", "新浪财经", "chart.bar.fill", "https://finance.sina.com.cn"),
            ]
        case .hk:
            return [
                ("腾讯回购股份计划持续", "AAStocks", "message.fill", "http://www.aastocks.com"),
                ("阿里巴巴云业务增长强劲", "AAStocks", "cloud.fill", "http://www.aastocks.com"),
                ("美团外卖业务盈利改善", "AAStocks", "bag.fill", "http://www.aastocks.com"),
                ("小米汽车订单超预期", "AAStocks", "car.fill", "http://www.aastocks.com"),
                ("港交所成交额回暖", "AAStocks", "building.columns.fill", "http://www.aastocks.com"),
            ]
        case .jp:
            return [
                ("トヨタ、EV戦略を加速", "日本経済新聞", "car.fill", "https://www.nikkei.com"),
                ("ソニー、ゲーム部門好調", "ロイター", "gamecontroller.fill", "https://jp.reuters.com"),
                ("任天堂、新型機の噂で上昇", "Yahoo!ファイナンス", "gamecontroller.fill", "https://finance.yahoo.co.jp"),
                ("ソフトバンクG、AI投資拡大", "ロイター", "brain.head.profile", "https://jp.reuters.com"),
                ("ユニクロ、海外売上増加", "日本経済新聞", "tshirt.fill", "https://www.nikkei.com"),
            ]
        }
    }

    private func quickLinks(for market: NewsMarket) -> [(name: String, icon: String, url: String)] {
        switch market {
        case .us:
            return [
                ("Yahoo Finance", "chart.line.uptrend.xyaxis", "https://finance.yahoo.com"),
                ("Bloomberg", "building.2.fill", "https://www.bloomberg.com/markets"),
                ("Reuters", "globe", "https://www.reuters.com/markets"),
                ("CNBC", "tv.fill", "https://www.cnbc.com/markets"),
                ("MarketWatch", "eye.fill", "https://www.marketwatch.com"),
            ]
        case .cn:
            return [
                ("东方财富", "chart.bar.fill", "https://www.eastmoney.com"),
                ("新浪财经", "s.circle.fill", "https://finance.sina.com.cn"),
                ("同花顺", "leaf.fill", "https://www.10jqka.com.cn"),
                ("财联社", "newspaper.fill", "https://www.cls.cn"),
                ("雪球", "snowflake", "https://xueqiu.com"),
            ]
        case .hk:
            return [
                ("经济日报", "dollarsign.circle.fill", "https://invest.hket.com"),
                ("信报", "doc.text.fill", "https://www.hkej.com"),
                ("AAStocks", "chart.xyaxis.line", "http://www.aastocks.com"),
                ("港交所", "building.columns.fill", "https://www.hkex.com.hk"),
                ("明报", "newspaper.fill", "https://finance.mingpao.com"),
            ]
        case .jp:
            return [
                ("NHK経済", "tv.fill", "https://www3.nhk.or.jp/news/cat05.html"),
                ("日経新聞", "n.circle.fill", "https://www.nikkei.com/markets"),
                ("Bloomberg JP", "b.circle.fill", "https://www.bloomberg.co.jp"),
                ("ロイター", "r.circle.fill", "https://jp.reuters.com"),
                ("株探", "magnifyingglass", "https://kabutan.jp"),
            ]
        }
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = UIColor.systemBlue
        return safari
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Featured News Card

struct FeaturedNewsCard: View {
    let title: String
    let subtitle: String
    let source: String
    let timeAgo: String
    let imageIcon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 图片占位
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
                .overlay {
                    Image(systemName: imageIcon)
                        .font(.system(size: 32))
                        .foregroundStyle(Color.blue.opacity(0.5))
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 8) {
                    Text(source)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.blue)

                    if !timeAgo.isEmpty {
                        Text("·")
                            .foregroundStyle(AppColors.textTertiary)
                        Text(timeAgo)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("阅读全文")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }
}

struct FeaturedNewsCardLoading: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.elevatedSurface)
                .frame(height: 120)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.elevatedSurface)
                    .frame(height: 20)

                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.elevatedSurface)
                    .frame(width: 200, height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.elevatedSurface)
                    .frame(width: 120, height: 14)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }
}

// MARK: - News Row

struct NewsRow: View {
    let title: String
    let source: String
    var timeAgo: String = ""
    var iconName: String = "newspaper"
    var accentColor: Color = .blue

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Text(source)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accentColor)

                    if !timeAgo.isEmpty {
                        Text("·")
                            .foregroundStyle(AppColors.textTertiary)
                        Text(timeAgo)
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct NewsRowLoading: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.elevatedSurface)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.elevatedSurface)
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.elevatedSurface)
                    .frame(width: 100, height: 12)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Quick Link Card

struct QuickLinkCard: View {
    let name: String
    let icon: String
    var color: Color = .blue

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }

            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }
}

#Preview {
    NewsView()
}
