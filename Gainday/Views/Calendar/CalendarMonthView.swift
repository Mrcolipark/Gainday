import SwiftUI

struct CalendarMonthView: View {
    let month: Date
    let snapshots: [Date: DailySnapshot]
    let onDateTap: (Date) -> Void

    // 7 columns with larger spacing for a more spacious feel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdayLabels = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        VStack(spacing: 10) {
            // Weekday headers with glass pill styling
            weekdayHeader

            // Calendar grid with increased spacing
            calendarGrid

            // Color legend
            colorLegend
        }
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: 6) {
            ForEach(weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.elevatedSurface)
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            let days = month.calendarDays()
            ForEach(Array(days.enumerated()), id: \.offset) { index, date in
                if let date = date {
                    let row = index / 7
                    let col = index % 7
                    CalendarDayCell(
                        date: date,
                        snapshot: snapshots[date.startOfDay],
                        isToday: date.isToday,
                        row: row,
                        col: col
                    )
                    .onTapGesture {
                        onDateTap(date)
                    }
                } else {
                    // Empty cell placeholder
                    Color.clear
                        .frame(minHeight: 52)
                }
            }
        }
    }

    // MARK: - Color Legend

    private var colorLegend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Text("亏损")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                HStack(spacing: 2) {
                    ForEach([-4.0, -2.0, -0.5], id: \.self) { pct in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.pnlColor(percent: pct))
                            .frame(width: 14, height: 14)
                    }
                }
            }

            Spacer()

            RoundedRectangle(cornerRadius: 3)
                .fill(AppColors.elevatedSurface)
                .frame(width: 14, height: 14)
                .overlay {
                    Text("无")
                        .font(.system(size: 6))
                        .foregroundStyle(AppColors.textTertiary)
                }

            Spacer()

            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach([0.5, 2.0, 4.0], id: \.self) { pct in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.pnlColor(percent: pct))
                            .frame(width: 14, height: 14)
                    }
                }
                Text("盈利")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.elevatedSurface)
        }
    }
}

#Preview {
    CalendarMonthView(
        month: Date(),
        snapshots: [:],
        onDateTap: { _ in }
    )
    .padding()
}
