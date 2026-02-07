import SwiftUI
import SwiftData

/// NISA 概览页面 - 专注于额度信息展示
struct NISAOverviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]

    @AppStorage("baseCurrency") private var baseCurrency = "JPY"

    /// NISA 账户列表
    private var nisaPortfolios: [Portfolio] {
        portfolios.filter { $0.isNISA }
    }

    /// つみたて账户
    private var tsumitatePortfolios: [Portfolio] {
        portfolios.filter { $0.accountTypeEnum == .nisa_tsumitate }
    }

    /// 成長账户
    private var growthPortfolios: [Portfolio] {
        portfolios.filter { $0.accountTypeEnum == .nisa_growth }
    }

    private var quota: NISAOverallQuota {
        NISAQuotaCalculator.calculateOverall(holdings: portfolios.flatMap(\.holdings))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 总体额度概览
                    overallQuotaSection

                    // 年度使用情况
                    annualQuotaSection

                    // NISA 规则说明
                    nisaRulesSection

                    // 空状态
                    if nisaPortfolios.isEmpty {
                        emptyStateView
                    }
                }
                .padding()
            }
            .background(AppColors.background)
            .navigationTitle("NISA 概览".localized)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成".localized) { dismiss() }
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
    }

    // MARK: - 总体额度概览

    private var overallQuotaSection: some View {
        VStack(spacing: 16) {
            // 生涯投資枠
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("生涯投资".localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()

                    Text("非課税枠".localized + " 1,800" + "万円".localized)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                }

                // 进度环和数值
                HStack(spacing: 24) {
                    NISACircularProgress(quota: quota, size: 100, lineWidth: 10)

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("已使用".localized)
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textTertiary)

                            Text(quota.formatManYen(quota.totalLifetimeUsed))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("剩余额度".localized)
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textTertiary)

                            Text(quota.formatManYen(quota.lifetimeRemaining))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppColors.profit)
                        }
                    }

                    Spacer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - 年度使用情况

    private var annualQuotaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(quota.year)" + "年度投资".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text(quota.formatManYen(quota.totalAnnualUsed) + " / " + quota.formatManYen(quota.totalAnnualLimit))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            // つみたて枠年度进度
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(AccountType.nisa_tsumitate.color)
                        .frame(width: 8, height: 8)

                    Text("つみたて投資枠".localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()
                }

                NISAProgressBar(
                    used: quota.tsumitateAnnualUsed,
                    limit: quota.tsumitateAnnualLimit,
                    label: nil,
                    height: 6,
                    showLabel: true,
                    color: AccountType.nisa_tsumitate.color
                )
            }

            // 成長枠年度进度
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(AccountType.nisa_growth.color)
                        .frame(width: 8, height: 8)

                    Text("成長投資枠".localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()
                }

                NISAProgressBar(
                    used: quota.growthAnnualUsed,
                    limit: quota.growthAnnualLimit,
                    label: nil,
                    height: 6,
                    showLabel: true,
                    color: AccountType.nisa_growth.color
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - NISA 规则说明

    private var nisaRulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textSecondary)

                Text("NISA 制度说明".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ruleRow(
                    icon: "leaf.fill",
                    color: AccountType.nisa_tsumitate.color,
                    title: "つみたて投資枠",
                    description: "年間120万円・只能購入対象投資信託".localized
                )

                Divider()
                    .background(AppColors.dividerColor)

                ruleRow(
                    icon: "chart.line.uptrend.xyaxis",
                    color: AccountType.nisa_growth.color,
                    title: "成長投資枠",
                    description: "年間240万円・日本股票和投資信託".localized
                )

                Divider()
                    .background(AppColors.dividerColor)

                ruleRow(
                    icon: "infinity",
                    color: .purple,
                    title: "生涯非課税枠",
                    description: "合計1,800万円（うち成長枠1,200万円まで）".localized
                )

                Divider()
                    .background(AppColors.dividerColor)

                ruleRow(
                    icon: "arrow.triangle.2.circlepath",
                    color: .orange,
                    title: "枠の再利用",
                    description: "売却した場合、翌年に枠が復活".localized
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.elevatedSurface)
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private func ruleRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textTertiary)

            VStack(spacing: 8) {
                Text("暂无 NISA 持仓")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("添加 NISA 持仓后，将在此显示额度使用情况")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

}

#Preview {
    NISAOverviewView()
        .modelContainer(for: Portfolio.self, inMemory: true)
        .preferredColorScheme(.dark)
}
