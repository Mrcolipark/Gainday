import SwiftUI

/// 日历日期格子 - 统一设计语言
struct CalendarDayCell: View {
    let date: Date
    let snapshot: DailySnapshot?
    let isToday: Bool
    let row: Int
    let col: Int

    init(date: Date, snapshot: DailySnapshot?, isToday: Bool, row: Int = 0, col: Int = 0) {
        self.date = date
        self.snapshot = snapshot
        self.isToday = isToday
        self.row = row
        self.col = col
    }

    private var pnlPercent: Double? {
        snapshot?.dailyPnLPercent
    }

    private var backgroundColor: Color {
        guard let pct = pnlPercent else {
            return AppColors.elevatedSurface
        }
        return AppColors.pnlColor(percent: pct)
    }

    private var glowColor: Color {
        guard let pct = pnlPercent else { return .clear }
        return pct >= 0 ? AppColors.profit : AppColors.loss
    }

    private var glowIntensity: Double {
        guard let pct = pnlPercent else { return 0 }
        return min(abs(pct) / 5.0, 1.0) * 0.4
    }

    private var textColor: Color {
        guard snapshot != nil else {
            return AppColors.textPrimary
        }
        // 有数据时始终使用白色文字（深色饱和背景）
        return .white
    }

    private var secondaryTextColor: Color {
        guard snapshot != nil else {
            return AppColors.textSecondary
        }
        // 有数据时使用半透明白色
        return .white.opacity(0.85)
    }

    @State private var todayGlow = false

    var body: some View {
        VStack(spacing: 3) {
            // 日期数字
            Text(date.dayString)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isToday ? .white : textColor.opacity(0.85))

            if let snapshot = snapshot {
                // 盈亏金额
                Text(snapshot.dailyPnL.compactFormatted(showSign: true))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isToday ? .white : textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // 盈亏百分比
                Text(snapshot.dailyPnLPercent.percentFormatted())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(isToday ? .white.opacity(0.9) : secondaryTextColor)
                    .lineLimit(1)
            } else {
                // 空白占位
                Text(" ")
                    .font(.system(size: 11, weight: .bold))
                Text(" ")
                    .font(.system(size: 9))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background {
            if isToday {
                todayBackground
            } else {
                normalBackground
            }
        }
        .heatmapCellAppearance(row: row, col: col)
    }

    // MARK: - 今日背景

    /// 今日格子的主题色（根据盈亏决定）
    private var todayColor: Color {
        guard let pct = pnlPercent else {
            return AppColors.profit  // 无数据时默认绿色
        }
        return pct >= 0 ? AppColors.profit : AppColors.loss
    }

    private var todayBackground: some View {
        ZStack {
            // 主背景
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [todayColor, todayColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 高光
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // 呼吸边框
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(todayGlow ? 0.6 : 0.3), lineWidth: 1.5)
                .scaleEffect(todayGlow ? 1.02 : 1.0)
        }
        .shadow(color: todayColor.opacity(todayGlow ? 0.6 : 0.4), radius: todayGlow ? 8 : 5, x: 0, y: 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                todayGlow = true
            }
        }
    }

    // MARK: - 普通背景

    private var normalBackground: some View {
        ZStack {
            // 主背景
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundColor)

            // 有数据时的高光效果
            if snapshot != nil {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )

                // 内边框
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .clear, .black.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        }
        .shadow(color: glowColor.opacity(glowIntensity), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 8) {
        HStack(spacing: 6) {
            CalendarDayCell(date: Date(), snapshot: nil, isToday: true)
            CalendarDayCell(
                date: Date().adding(days: -1),
                snapshot: {
                    let s = DailySnapshot()
                    s.dailyPnL = 52340
                    s.dailyPnLPercent = 3.5
                    return s
                }(),
                isToday: false,
                row: 0, col: 1
            )
            CalendarDayCell(
                date: Date().adding(days: -2),
                snapshot: {
                    let s = DailySnapshot()
                    s.dailyPnL = 12340
                    s.dailyPnLPercent = 1.2
                    return s
                }(),
                isToday: false,
                row: 0, col: 2
            )
        }
        HStack(spacing: 6) {
            CalendarDayCell(
                date: Date().adding(days: -3),
                snapshot: {
                    let s = DailySnapshot()
                    s.dailyPnL = -25600
                    s.dailyPnLPercent = -2.8
                    return s
                }(),
                isToday: false,
                row: 1, col: 0
            )
            CalendarDayCell(
                date: Date().adding(days: -4),
                snapshot: {
                    let s = DailySnapshot()
                    s.dailyPnL = -5600
                    s.dailyPnLPercent = -0.6
                    return s
                }(),
                isToday: false,
                row: 1, col: 1
            )
            CalendarDayCell(date: Date().adding(days: -5), snapshot: nil, isToday: false, row: 1, col: 2)
        }
    }
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
