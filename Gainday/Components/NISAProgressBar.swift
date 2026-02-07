import SwiftUI

/// NISA 额度进度条组件
struct NISAProgressBar: View {
    let used: Double          // 已使用金额
    let limit: Double         // 上限金额
    let label: String?        // 可选标签
    var height: CGFloat = 8
    var showLabel: Bool = true
    var color: Color = AppColors.profit

    private var ratio: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, used / limit)
    }

    private var usedInManYen: Double { used / 10000 }
    private var limitInManYen: Double { limit / 10000 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showLabel {
                HStack {
                    if let label = label {
                        Text(label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Text(formatProgress())
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(progressColor)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(AppColors.elevatedSurface)

                    // 进度条
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(progressGradient)
                        .frame(width: max(0, geometry.size.width * ratio))
                }
            }
            .frame(height: height)
        }
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var progressColor: Color {
        if ratio >= 0.9 {
            return AppColors.loss  // 接近上限时警告色
        } else if ratio >= 0.7 {
            return .orange
        } else {
            return color
        }
    }

    private func formatProgress() -> String {
        if limitInManYen >= 100 {
            return String(format: "%.0f万/%.0f万", usedInManYen, limitInManYen)
        } else {
            return String(format: "%.1f万/%.0f万", usedInManYen, limitInManYen)
        }
    }
}

/// NISA 双进度条组件（显示年度和生涯额度）
struct NISADualProgressBar: View {
    let quota: NISAOverallQuota
    let accountType: AccountType

    var body: some View {
        VStack(spacing: 12) {
            // 年度额度
            if let annualLimit = accountType.annualLimit {
                let annualUsed = accountType == .nisa_tsumitate
                    ? quota.tsumitateAnnualUsed
                    : quota.growthAnnualUsed

                NISAProgressBar(
                    used: annualUsed,
                    limit: annualLimit,
                    label: "年度額度".localized,
                    color: accountType.color
                )
            }

            // 生涯额度（仅成長枠显示独立上限）
            if accountType == .nisa_growth {
                NISAProgressBar(
                    used: quota.growthLifetimeUsed,
                    limit: AccountType.growthLifetimeLimit,
                    label: "生涯額度".localized,
                    color: accountType.color.opacity(0.7)
                )
            }
        }
    }
}

/// 紧凑型进度条（用于卡片内显示）
struct NISACompactProgressBar: View {
    let used: Double
    let limit: Double
    var color: Color = AppColors.profit

    private var ratio: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, used / limit)
    }

    var body: some View {
        HStack(spacing: 8) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColors.elevatedSurface)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(0, geometry.size.width * ratio))
                }
            }
            .frame(height: 6)

            // 文字
            Text(formatCompact())
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize()
        }
    }

    private func formatCompact() -> String {
        let usedMan = used / 10000
        let limitMan = limit / 10000
        return String(format: "%.0f/%.0f万", usedMan, limitMan)
    }
}

/// NISA 总览进度环
struct NISACircularProgress: View {
    let quota: NISAOverallQuota
    var size: CGFloat = 120
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            // 背景环
            Circle()
                .stroke(AppColors.elevatedSurface, lineWidth: lineWidth)

            // つみたて枠进度（内环）
            Circle()
                .trim(from: 0, to: quota.tsumitateAnnualRatio * 0.5)
                .stroke(
                    AccountType.nisa_tsumitate.color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // 成長枠进度（外环的另一半）
            Circle()
                .trim(from: 0.5, to: 0.5 + quota.growthAnnualRatio * 0.5)
                .stroke(
                    AccountType.nisa_growth.color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // 中心文字
            VStack(spacing: 2) {
                Text(quota.formatManYen(quota.totalAnnualUsed))
                    .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text("/ \(quota.formatManYen(quota.totalAnnualLimit))")
                    .font(.system(size: size * 0.1, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 24) {
        NISAProgressBar(
            used: 800000,
            limit: 1200000,
            label: "つみたて投資枠",
            color: AccountType.nisa_tsumitate.color
        )

        NISACompactProgressBar(
            used: 1500000,
            limit: 2400000,
            color: AccountType.nisa_growth.color
        )

        NISACircularProgress(
            quota: NISAOverallQuota(
                tsumitateAnnualUsed: 800000,
                growthAnnualUsed: 1200000,
                tsumitateLifetimeUsed: 2000000,
                growthLifetimeUsed: 4000000,
                year: 2024
            )
        )
    }
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
