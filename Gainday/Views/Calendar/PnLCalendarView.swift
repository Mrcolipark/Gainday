import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

/// 盈亏日历 - 统一设计语言
struct PnLCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]

    @State private var currentMonth = Date()
    @State private var selectedDate: Date?
    @State private var showDayDetail = false
    @State private var viewMode: CalendarViewMode = .month
    @State private var showShareSheet = false
    @State private var snapshots: [Date: DailySnapshot] = [:]
    @State private var animateContent = false
    @State private var selectedPortfolioID: String? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var isGeneratingShare = false

    @AppStorage("baseCurrency") private var baseCurrency = "JPY"

    #if os(iOS)
    @State private var shareImage: UIImage?
    #endif

    enum CalendarViewMode: String, CaseIterable {
        case month = "月视图"
        case year = "年视图"
    }

    var body: some View {
        AppNavigationWrapper(title: "盈历") {
            ScrollView {
                VStack(spacing: 20) {
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
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                    // 视图模式切换
                    viewModeSelector
                        .padding(.horizontal, 16)

                    // 账户筛选
                    if portfolios.count > 1 {
                        portfolioFilterBar
                    }

                    // 内容区域
                    switch viewMode {
                    case .month:
                        monthViewContent
                    case .year:
                        yearViewContent
                    }
                }
                .padding(.bottom, 30)
            }
            .background(AppColors.background)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task {
                            await generateShareImage()
                        }
                    } label: {
                        if isGeneratingShare {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
                    .disabled(isGeneratingShare)
                }
            }
            .sheet(isPresented: $showDayDetail) {
                if let date = selectedDate {
                    DayDetailSheet(date: date, snapshot: snapshots[date.startOfDay])
                        .presentationDetents([.medium, .large])
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheetView(image: image)
                }
            }
            #endif
            .task {
                // 等待一小段时间确保 @Query 有机会加载
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
                await migrateHistoricalDataIfNeeded()
                await loadSnapshots()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animateContent = true
                }
            }
            .onChange(of: currentMonth) {
                Task { await loadSnapshots() }
            }
            .onChange(of: selectedPortfolioID) {
                Task { await loadSnapshots() }
            }
            .onChange(of: viewMode) {
                Task { await loadSnapshots() }
            }
            .onChange(of: portfolios) { _, newPortfolios in
                // 当 portfolios 加载完成后触发迁移（备用路径）
                if !newPortfolios.isEmpty && !hasMigrated {
                    Task {
                        await migrateHistoricalDataIfNeeded()
                        await loadSnapshots()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .portfolioDataDidChange)) { _ in
                // 持仓或交易数据变化时，重新生成今日快照并刷新
                Task {
                    await regenerateTodaySnapshot()
                    await loadSnapshots()
                }
            }
        }
    }

    // MARK: - 历史数据自动迁移

    @State private var hasMigrated = false

    private func migrateHistoricalDataIfNeeded() async {
        guard !hasMigrated else { return }
        guard !portfolios.isEmpty else {
            print("[Migration] Skipped: portfolios not loaded yet")
            return
        }
        hasMigrated = true

        print("[Migration] Starting migration for \(portfolios.count) portfolios...")
        await SnapshotService.shared.migrateHistoricalSnapshots(
            portfolios: portfolios,
            baseCurrency: baseCurrency,
            modelContext: modelContext
        )

        // 更新现有快照的个股盈亏数据
        await SnapshotService.shared.updateSnapshotsWithHoldingPnL(
            portfolios: portfolios,
            baseCurrency: baseCurrency,
            modelContext: modelContext
        )
        print("[Migration] Completed")
    }

    // MARK: - 视图模式切换

    private var viewModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(viewMode == mode ? .white : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            viewMode == mode ?
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppColors.profit) : nil
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - 账户筛选

    private var portfolioFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterPill(title: "全部", isSelected: selectedPortfolioID == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPortfolioID = nil
                    }
                }

                ForEach(portfolios) { portfolio in
                    FilterPill(
                        title: portfolio.name,
                        color: portfolio.tagColor,
                        isSelected: selectedPortfolioID == portfolio.id.uuidString
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPortfolioID = portfolio.id.uuidString
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 月视图

    private var monthViewContent: some View {
        VStack(spacing: 16) {
            // 月份导航栏
            monthNavigationBar
                .padding(.horizontal, 16)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 10)

            // 日历网格
            CalendarMonthView(
                month: currentMonth,
                snapshots: snapshots,
                onDateTap: { date in
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    selectedDate = date
                    showDayDetail = true
                }
            )
            .padding(.horizontal, 16)
            .opacity(animateContent ? 1 : 0)
            .offset(x: dragOffset)
            .gesture(swipeGesture)

            // 月度统计
            MonthStatsBar(snapshots: monthSnapshots, baseCurrency: baseCurrency)
                .padding(.horizontal, 16)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 10)
        }
    }

    private var monthNavigationBar: some View {
        HStack {
            // 上一月按钮
            Button {
                navigateMonth(by: -1)
            } label: {
                ZStack {
                    Circle()
                        .fill(AppColors.cardSurface)
                        .frame(width: 44, height: 44)

                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }

            Spacer()

            // 月份标题和收益
            VStack(spacing: 4) {
                Text(currentMonth.monthYearString)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                if let total = monthTotalPnL {
                    HStack(spacing: 6) {
                        Text("月度收益")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textTertiary)

                        Text(total.compactFormatted(showSign: true))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(total >= 0 ? AppColors.profit : AppColors.loss)
                    }
                }
            }

            Spacer()

            // 下一月按钮
            Button {
                navigateMonth(by: 1)
            } label: {
                ZStack {
                    Circle()
                        .fill(AppColors.cardSurface)
                        .frame(width: 44, height: 44)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation.width * 0.3
            }
            .onEnded { value in
                let threshold: CGFloat = 50
                if value.translation.width < -threshold {
                    navigateMonth(by: 1)
                } else if value.translation.width > threshold {
                    navigateMonth(by: -1)
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    dragOffset = 0
                }
            }
    }

    private func navigateMonth(by offset: Int) {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentMonth = currentMonth.adding(months: offset)
        }
    }

    // MARK: - 年视图

    private var yearViewContent: some View {
        VStack(spacing: 16) {
            YearHeatmapView(
                year: currentMonth.year,
                snapshots: snapshots
            )
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 数据

    private var monthSnapshots: [DailySnapshot] {
        let startOfMonth = currentMonth.startOfMonth
        let endOfMonth = currentMonth.endOfMonth
        return snapshots.values
            .filter { $0.date >= startOfMonth && $0.date <= endOfMonth }
            .sorted { $0.date < $1.date }
    }

    private var monthTotalPnL: Double? {
        let total = monthSnapshots.reduce(0) { $0 + $1.dailyPnL }
        return monthSnapshots.isEmpty ? nil : total
    }

    private func loadSnapshots() async {
        do {
            let snaps: [DailySnapshot]

            switch viewMode {
            case .month:
                // 月视图：只加载当月数据
                snaps = try SnapshotService.shared.fetchSnapshots(
                    for: currentMonth,
                    portfolioID: selectedPortfolioID,
                    modelContext: modelContext
                )
            case .year:
                // 年视图：加载整年数据
                snaps = try SnapshotService.shared.fetchYearSnapshots(
                    year: currentMonth.year,
                    portfolioID: selectedPortfolioID,
                    modelContext: modelContext
                )
            }

            var dict: [Date: DailySnapshot] = [:]
            for snap in snaps {
                dict[snap.date.startOfDay] = snap
            }
            snapshots = dict
        } catch {
            ErrorPresenter.shared.showToast("加载日历数据失败", type: .error)
        }
    }

    /// 重新生成今日快照（当持仓/交易数据变化时调用）
    private func regenerateTodaySnapshot() async {
        guard !portfolios.isEmpty else { return }

        // 获取最新行情
        var allSymbols: [String] = []
        for portfolio in portfolios {
            for holding in portfolio.holdings {
                allSymbols.append(holding.symbol)
            }
        }

        guard !allSymbols.isEmpty else { return }

        do {
            let quotesArray = try await MarketDataService.shared.fetchQuotes(symbols: allSymbols)
            // 转换为字典
            var quotes: [String: MarketDataService.QuoteData] = [:]
            for quote in quotesArray {
                quotes[quote.symbol] = quote
            }

            // 获取汇率
            var currencies: [String] = [baseCurrency]
            for portfolio in portfolios {
                currencies.append(portfolio.baseCurrency)
                for holding in portfolio.holdings {
                    currencies.append(holding.currency)
                }
            }
            await CurrencyService.shared.refreshRates(currencies: currencies, baseCurrency: baseCurrency)

            var rates: [String: Double] = [:]
            for currency in currencies where currency != baseCurrency {
                if let rate = await CurrencyService.shared.getCachedRate(from: currency, to: baseCurrency) {
                    rates["\(currency)\(baseCurrency)"] = rate
                }
            }

            // 重新生成今日快照
            await SnapshotService.shared.saveOrUpdateTodaySnapshot(
                portfolios: portfolios,
                quotes: quotes,
                rates: rates,
                baseCurrency: baseCurrency,
                modelContext: modelContext
            )
        } catch {
            print("[Calendar] Failed to regenerate today snapshot: \(error)")
        }
    }

    @MainActor
    private func generateShareImage() async {
        #if os(iOS)
        isGeneratingShare = true

        // 给 SwiftUI 一个渲染周期，确保视图已完成布局
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 秒

        let image: UIImage?

        switch viewMode {
        case .month:
            image = ShareImageService.renderShareImage(
                month: currentMonth,
                snapshots: Array(snapshots.values),
                baseCurrency: baseCurrency
            )
        case .year:
            image = ShareImageService.renderYearShareImage(
                year: currentMonth.year,
                snapshots: snapshots,
                baseCurrency: baseCurrency
            )
        }

        isGeneratingShare = false
        shareImage = image
        showShareSheet = image != nil
        #endif
    }
}

// MARK: - 筛选标签

private struct FilterPill: View {
    let title: String
    var color: Color = AppColors.profit
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected && title != "全部" {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? (title == "全部" ? AppColors.profit : color) : AppColors.cardSurface)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 分享 Sheet

#if os(iOS)
struct ShareSheetView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 预览图片
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
                        .padding(.horizontal, 20)

                    // 分享按钮
                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview("投资月报", image: Image(uiImage: image))
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                            Text("分享")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppColors.profit)
                        )
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .background(AppColors.background)
            .navigationTitle("分享月报")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
    }
}
#endif

#Preview {
    PnLCalendarView()
        .modelContainer(for: [DailySnapshot.self, Portfolio.self], inMemory: true)
        .preferredColorScheme(.dark)
}
