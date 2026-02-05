import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ShareCardView: View {
    let month: Date
    let snapshots: [DailySnapshot]
    let baseCurrency: String
    let format: ShareImageService.ShareFormat

    private let weekdayLabels = ["日", "一", "二", "三", "四", "五", "六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    private var monthSnapMap: [Date: DailySnapshot] {
        var map: [Date: DailySnapshot] = [:]
        for snap in snapshots {
            map[snap.date.startOfDay] = snap
        }
        return map
    }

    private var totalPnL: Double {
        snapshots.reduce(0) { $0 + $1.dailyPnL }
    }

    private var profitDays: Int {
        snapshots.filter { $0.dailyPnL > 0 }.count
    }

    private var lossDays: Int {
        snapshots.filter { $0.dailyPnL < 0 }.count
    }

    private var winRate: Double {
        let total = profitDays + lossDays
        guard total > 0 else { return 0 }
        return Double(profitDays) / Double(total) * 100
    }

    init(
        month: Date,
        snapshots: [DailySnapshot],
        baseCurrency: String,
        format: ShareImageService.ShareFormat = .square
    ) {
        self.month = month
        self.snapshots = snapshots
        self.baseCurrency = baseCurrency
        self.format = format
    }

    var body: some View {
        ZStack {
            // Background gradient
            AppColors.shareCardGradient
                .ignoresSafeArea()

            VStack(spacing: format == .story ? 24 : 16) {
                // Header
                VStack(spacing: 4) {
                    Text(month.monthYearString)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("投资月报")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, format == .story ? 40 : 16)

                // Calendar grid
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        ForEach(weekdayLabels, id: \.self) { label in
                            Text(label)
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 3) {
                        ForEach(Array(month.calendarDays().enumerated()), id: \.offset) { _, date in
                            if let date = date {
                                let snap = monthSnapMap[date.startOfDay]
                                let pct = snap?.dailyPnLPercent ?? 0
                                let hasData = snap != nil

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(hasData ? AppColors.pnlColor(percent: pct) : Color.white.opacity(0.05))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        Text(date.dayString)
                                            .font(.system(size: 8, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                            } else {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)

                // Stats
                VStack(spacing: 8) {
                    HStack {
                        Text("本月盈亏")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text(totalPnL.currencyFormatted(code: baseCurrency, showSign: true))
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(totalPnL >= 0 ? Color.green : Color.red)
                    }

                    HStack {
                        Text("盈利 \(profitDays)天 / 亏损 \(lossDays)天")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text(String(format: "胜率 %.1f%%", winRate))
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 12)

                Spacer()

                // Footer with QR code
                HStack {
                    #if os(iOS)
                    if let qrImage = ShareImageService.generateQRCode(from: "https://apps.apple.com") {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    #endif

                    VStack(alignment: .leading, spacing: 2) {
                        Text("GainDay")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                        Text("盈历 - 投资日历")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, format == .story ? 40 : 16)
            }
        }
        .frame(width: format.size.width, height: format.size.height)
    }
}

#Preview {
    ShareCardView(
        month: Date(),
        snapshots: [],
        baseCurrency: "JPY",
        format: .square
    )
}
