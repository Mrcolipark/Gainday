import SwiftUI

struct NewsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCategory = 0
    @State private var animateContent = false

    private let categories = ["All", "Markets", "Stocks", "Crypto"]

    var body: some View {
        AppNavigationWrapper(title: "News") {
            ScrollView {
                VStack(spacing: 16) {
                    // 品牌标题
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
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    // Category filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(categories.enumerated()), id: \.offset) { index, category in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedCategory = index
                                    }
                                } label: {
                                    Text(category)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(selectedCategory == index ? .white : AppColors.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background {
                                            if selectedCategory == index {
                                                Capsule()
                                                    .fill(Color.blue)
                                            } else {
                                                Capsule()
                                                    .fill(AppColors.elevatedSurface)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .opacity(animateContent ? 1 : 0)

                    // Featured article placeholder
                    GlassCard(tint: .blue) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Placeholder featured image
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.15), .purple.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 160)
                                .overlay {
                                    VStack(spacing: 12) {
                                        Image(systemName: "newspaper.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(AppColors.textTertiary)
                                        Text("Financial News")
                                            .font(.headline)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Coming Soon")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text("Financial news feed will be available in a future update. Stay tuned for real-time market news and analysis.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 15)

                    // Quick links
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text("Quick Links")
                                .font(AppFonts.cardTitle)
                            Spacer()
                        }
                        .padding(.horizontal)

                        ForEach(quickLinks, id: \.title) { link in
                            Link(destination: URL(string: link.url)!) {
                                NewsArticleRow(
                                    title: link.title,
                                    source: link.source,
                                    timeAgo: link.timeAgo,
                                    iconName: link.icon
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 10)
                }
                .padding(.bottom, 20)
            }
            .background(newsBackground)
            .task {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animateContent = true
                }
            }
        }
    }

    // MARK: - Background

    private var newsBackground: some View {
        AppColors.background
            .ignoresSafeArea()
    }

    // MARK: - Quick Links Data

    private var quickLinks: [(title: String, source: String, timeAgo: String, icon: String, url: String)] {
        [
            ("Yahoo Finance - Markets", "finance.yahoo.com", "Live", "chart.line.uptrend.xyaxis", "https://finance.yahoo.com"),
            ("Bloomberg Markets", "bloomberg.com", "Live", "building.2", "https://www.bloomberg.com/markets"),
            ("Reuters Business", "reuters.com", "Live", "globe", "https://www.reuters.com/business"),
            ("CNBC Markets", "cnbc.com", "Live", "tv", "https://www.cnbc.com/markets"),
            ("日経新聞 - マーケット", "nikkei.com", "Live", "yensign.circle", "https://www.nikkei.com/markets"),
            ("Yahoo Finance Japan", "finance.yahoo.co.jp", "Live", "chart.bar.fill", "https://finance.yahoo.co.jp"),
        ]
    }
}

// MARK: - News Article Row

struct NewsArticleRow: View {
    let title: String
    let source: String
    let timeAgo: String
    var iconName: String = "newspaper"

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.elevatedSurface)
                    .frame(width: 56, height: 56)
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("·")
                        .foregroundStyle(AppColors.textTertiary)
                    Text(timeAgo)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

#Preview {
    NewsView()
}
