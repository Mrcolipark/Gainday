import SwiftUI

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

    /// Glow color based on P&L direction
    private var glowColor: Color {
        guard let pct = pnlPercent else { return .clear }
        return pct >= 0 ? .green : .red
    }

    /// Glow intensity scales with P&L magnitude
    private var glowIntensity: Double {
        guard let pct = pnlPercent else { return 0 }
        return min(abs(pct) / 5.0, 1.0) * 0.5
    }

    /// Text color for readability on colored backgrounds
    private var textColor: Color {
        guard let pct = pnlPercent else {
            return AppColors.textPrimary
        }
        // For strong colors, use white text
        if abs(pct) > 1.5 {
            return .white
        }
        return AppColors.textPrimary
    }

    private var secondaryTextColor: Color {
        guard let pct = pnlPercent else {
            return AppColors.textSecondary
        }
        if abs(pct) > 1.5 {
            return .white.opacity(0.85)
        }
        return AppColors.textSecondary
    }

    @State private var todayGlow = false

    var body: some View {
        VStack(spacing: 2) {
            // Day number - top
            Text(date.dayString)
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundStyle(isToday ? .white : textColor.opacity(0.8))

            if let snapshot = snapshot {
                // P&L Amount - middle (main focus)
                Text(snapshot.dailyPnL.compactFormatted(showSign: true))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isToday ? .white : textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // P&L Percent - bottom
                Text(snapshot.dailyPnLPercent.percentFormatted())
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(isToday ? .white.opacity(0.9) : secondaryTextColor)
                    .lineLimit(1)
            } else {
                // Empty placeholder to maintain height
                Text(" ")
                    .font(.system(size: 10, weight: .bold))
                Text(" ")
                    .font(.system(size: 8))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background {
            if isToday {
                todayBackground
            } else {
                normalBackground
            }
        }
        .heatmapCellAppearance(row: row, col: col)
    }

    // MARK: - Today Background

    private var todayBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            // Pulsing glow border for today
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(todayGlow ? 0.6 : 0.3), lineWidth: 1.5)
                .scaleEffect(todayGlow ? 1.02 : 1.0)
        }
        .shadow(color: .blue.opacity(todayGlow ? 0.6 : 0.4), radius: todayGlow ? 8 : 5, x: 0, y: 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                todayGlow = true
            }
        }
    }

    // MARK: - Normal Background

    private var normalBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundColor)

            // Glass highlight on colored cells
            if snapshot != nil {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )

                // Inner shadow for depth
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.black.opacity(0.1), .clear, .white.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }

            // Subtle border
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(snapshot != nil ? 0.15 : 0.08), lineWidth: 0.5)
        }
        // Colored glow shadow for data cells
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
}
