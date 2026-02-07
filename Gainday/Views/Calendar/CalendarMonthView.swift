import SwiftUI

/// 月历网格 - 统一设计语言
struct CalendarMonthView: View {
    let month: Date
    let snapshots: [Date: DailySnapshot]
    let onDateTap: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private var weekdayLabels: [String] {
        ["周日".localized, "一".localized, "二".localized, "三".localized, "四".localized, "五".localized, "六".localized]
    }

    var body: some View {
        VStack(spacing: 12) {
            // 星期头部
            weekdayHeader

            // 日历网格
            calendarGrid

            // 颜色图例
            colorLegend
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - 星期头部

    private var weekdayHeader: some View {
        HStack(spacing: 6) {
            ForEach(weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppColors.elevatedSurface)
        )
    }

    // MARK: - 日历网格

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
                    Color.clear
                        .frame(minHeight: 56)
                }
            }
        }
    }

    // MARK: - 颜色图例

    private var colorLegend: some View {
        HStack(spacing: 0) {
            // 亏损
            HStack(spacing: 6) {
                Text("亏损".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.loss)

                HStack(spacing: 3) {
                    ForEach([-3.0, -1.0, -0.3], id: \.self) { pct in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AppColors.pnlColor(percent: pct))
                            .frame(width: 16, height: 16)
                    }
                }
            }

            Spacer()

            // 无数据
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(AppColors.elevatedSurface)
                    .frame(width: 16, height: 16)

                Text("无数据".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textTertiary)
            }

            Spacer()

            // 盈利
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    ForEach([0.3, 1.0, 3.0], id: \.self) { pct in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AppColors.pnlColor(percent: pct))
                            .frame(width: 16, height: 16)
                    }
                }

                Text("盈利".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.profit)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppColors.elevatedSurface)
        )
    }
}

#Preview {
    CalendarMonthView(
        month: Date(),
        snapshots: [:],
        onDateTap: { _ in }
    )
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
