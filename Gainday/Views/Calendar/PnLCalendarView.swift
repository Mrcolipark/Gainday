import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct PnLCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]
    @State private var currentMonth = Date()
    @State private var selectedDate: Date?
    @State private var showDayDetail = false
    @State private var viewMode: CalendarViewMode = .month
    @State private var showShareSheet = false
    @State private var snapshots: [Date: DailySnapshot] = [:]
    @State private var baseCurrency = "JPY"
    @State private var animateContent = false
    @State private var selectedPortfolioID: String? = nil
    @State private var dragOffset: CGFloat = 0

    #if os(iOS)
    @State private var shareImage: UIImage?
    #endif

    enum CalendarViewMode: String, CaseIterable {
        case month = "月"
        case year = "年"
    }

    var body: some View {
        AppNavigationWrapper(title: "Calendar") {
            ScrollView {
                VStack(spacing: 12) {
                    // View mode picker with glass styling
                    Picker("视图", selection: $viewMode) {
                        ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Portfolio filter picker
                    if portfolios.count > 1 {
                        portfolioFilterBar
                    }

                    switch viewMode {
                    case .month:
                        monthView
                    case .year:
                        yearView
                    }
                }
                .padding(.bottom, 20)
            }
            .background(calendarBackground)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        generateShareImage()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body.weight(.medium))
                    }
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
                await loadSnapshots()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animateContent = true
                }
            }
            .onChange(of: currentMonth) {
                Task { await loadSnapshots() }
            }
        }
    }

    // MARK: - Portfolio Filter Bar

    private var portfolioFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(title: "全部", isSelected: selectedPortfolioID == nil) {
                    selectedPortfolioID = nil
                }
                ForEach(portfolios) { portfolio in
                    FilterPill(
                        title: portfolio.name,
                        color: portfolio.tagColor,
                        isSelected: selectedPortfolioID == portfolio.id.uuidString
                    ) {
                        selectedPortfolioID = portfolio.id.uuidString
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Background

    private var calendarBackground: some View {
        AppColors.background
            .ignoresSafeArea()
    }

    // MARK: - Month View

    private var monthView: some View {
        VStack(spacing: 12) {
            // Liquid Glass styled month navigation bar
            monthNavigationBar
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 10)

            // Main calendar with swipe gesture
            CalendarMonthView(
                month: currentMonth,
                snapshots: snapshots,
                onDateTap: { date in
                    selectedDate = date
                    showDayDetail = true
                }
            )
            .padding(.horizontal, 12)
            .opacity(animateContent ? 1 : 0)
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width * 0.3
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        if value.translation.width < -threshold {
                            // Swipe left -> next month
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentMonth = currentMonth.adding(months: 1)
                                dragOffset = 0
                            }
                        } else if value.translation.width > threshold {
                            // Swipe right -> previous month
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentMonth = currentMonth.adding(months: -1)
                                dragOffset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )

            // Month statistics
            MonthStatsBar(snapshots: monthSnapshots, baseCurrency: baseCurrency)
                .padding(.horizontal)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 10)
        }
    }

    private var monthNavigationBar: some View {
        HStack {
            Button {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    currentMonth = currentMonth.adding(months: -1)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                        }
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text(currentMonth.monthYearString)
                    .font(.system(.title2, design: .default, weight: .bold))
                if let total = monthTotalPnL {
                    HStack(spacing: 4) {
                        Text("月度收益")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Text(total.compactFormatted(showSign: true))
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(total >= 0 ? AppColors.profit : AppColors.loss)
                    }
                }
            }

            Spacer()

            Button {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    currentMonth = currentMonth.adding(months: 1)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                        }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                }
        }
        .padding(.horizontal)
    }

    // MARK: - Year View

    private var yearView: some View {
        ScrollView {
            YearHeatmapView(
                year: currentMonth.year,
                snapshots: snapshots
            )
            .padding()
        }
    }

    // MARK: - Data

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
            let monthSnaps = try await SnapshotService.shared.fetchSnapshots(
                for: currentMonth,
                modelContext: modelContext
            )
            var dict: [Date: DailySnapshot] = [:]
            for snap in monthSnaps {
                dict[snap.date.startOfDay] = snap
            }
            snapshots = dict
        } catch {
            ErrorPresenter.shared.showToast("加载日历数据失败", type: .error)
        }
    }

    private func generateShareImage() {
        #if os(iOS)
        let image = ShareImageService.renderShareImage(
            month: currentMonth,
            snapshots: Array(snapshots.values),
            baseCurrency: baseCurrency
        )
        shareImage = image
        showShareSheet = image != nil
        #endif
    }
}

// MARK: - Filter Pill

private struct FilterPill: View {
    let title: String
    var color: Color = .blue
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? .white : AppColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(color)
                    } else {
                        Capsule()
                            .fill(AppColors.elevatedSurface)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Sheet

#if os(iOS)
struct ShareSheetView: View {
    let image: UIImage

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
                    .padding()

                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview("投资月报", image: Image(uiImage: image))
                ) {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .blue.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.white.opacity(0.2), .clear],
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                            }
                        }
                        .foregroundStyle(.white)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal)
            }
            .navigationTitle("分享月报")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif

#Preview {
    PnLCalendarView()
        .modelContainer(for: [DailySnapshot.self, Portfolio.self], inMemory: true)
}
