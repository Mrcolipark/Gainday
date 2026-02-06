import SwiftUI
import SwiftData

/// 账户管理详情页 - 统一设计语言
struct AccountManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var portfolio: Portfolio

    @State private var editedName: String = ""
    @State private var editedAccountType: AccountType = .normal
    @State private var editedBaseCurrency: BaseCurrency = .JPY
    @State private var editedColorTag: String = "blue"
    @State private var showDeleteConfirmation = false
    @State private var holdingToDelete: Holding?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 账户信息
                accountInfoSection

                // 标识颜色
                colorSection

                // 持仓列表
                holdingsSection

                // 危险区域
                dangerSection

                Spacer(minLength: 40)
            }
            .padding(16)
        }
        .background(AppColors.background)
        .navigationTitle(portfolio.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            editedName = portfolio.name
            editedAccountType = portfolio.accountTypeEnum
            editedBaseCurrency = portfolio.baseCurrencyEnum
            editedColorTag = portfolio.colorTag
        }
        .onDisappear {
            // 保存更改
            portfolio.name = editedName
            portfolio.accountType = editedAccountType.rawValue
            portfolio.baseCurrency = editedBaseCurrency.rawValue
            portfolio.colorTag = editedColorTag
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {
                holdingToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let holding = holdingToDelete {
                    if let index = portfolio.holdings.firstIndex(where: { $0.id == holding.id }) {
                        portfolio.holdings.remove(at: index)
                    }
                    modelContext.delete(holding)
                    holdingToDelete = nil
                    // 通知日历视图刷新
                    NotificationCenter.default.post(name: .portfolioDataDidChange, object: nil)
                }
            }
        } message: {
            if let holding = holdingToDelete {
                Text("确定要删除「\(holding.name)」吗？\n\n该持仓的所有交易记录都将被永久删除。")
            }
        }
    }

    // MARK: - 账户信息

    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("账户信息", icon: "building.columns.fill")

            VStack(spacing: 16) {
                // 账户名称
                VStack(alignment: .leading, spacing: 8) {
                    Text("账户名称")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    TextField(
                        "",
                        text: $editedName,
                        prompt: Text("账户名称")
                            .foregroundStyle(AppColors.textTertiary)
                    )
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppColors.elevatedSurface)
                    )
                }

                // 账户类型
                VStack(alignment: .leading, spacing: 8) {
                    Text("账户类型")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(AccountType.allCases) { type in
                                Button {
                                    editedAccountType = type
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: type.iconName)
                                            .font(.system(size: 14))
                                        Text(type.displayName)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundStyle(editedAccountType == type ? .white : AppColors.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(editedAccountType == type ? AppColors.profit : AppColors.elevatedSurface)
                                    )
                                }
                            }
                        }
                    }
                }

                // 基准货币
                VStack(alignment: .leading, spacing: 8) {
                    Text("基准货币")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    HStack(spacing: 10) {
                        ForEach(BaseCurrency.allCases) { currency in
                            Button {
                                editedBaseCurrency = currency
                            } label: {
                                Text(currency.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(editedBaseCurrency == currency ? .white : AppColors.textSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(editedBaseCurrency == currency ? AppColors.profit : AppColors.elevatedSurface)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - 标识颜色

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("标识颜色", icon: "paintpalette.fill")

            VStack(spacing: 16) {
                // 预览
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.tagColor(editedColorTag), AppColors.tagColor(editedColorTag).opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .shadow(color: AppColors.tagColor(editedColorTag).opacity(0.4), radius: 8, x: 0, y: 4)

                        Image(systemName: editedAccountType.iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(editedName.isEmpty ? "账户名称" : editedName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("\(editedAccountType.displayName) · \(editedBaseCurrency.rawValue)")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.elevatedSurface)
                )

                // 颜色选择
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                    ForEach(AppColors.accountTagKeys, id: \.self) { key in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                editedColorTag = key
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.tagColor(key), AppColors.tagColor(key).opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                    .shadow(color: AppColors.tagColor(key).opacity(editedColorTag == key ? 0.5 : 0), radius: 8, x: 0, y: 4)

                                if editedColorTag == key {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .scaleEffect(editedColorTag == key ? 1.1 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - 持仓列表

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("持仓 (\(portfolio.holdings.count))", icon: "chart.pie.fill")

            if portfolio.holdings.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.textTertiary)

                    Text("暂无持仓")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textSecondary)

                    Text("在主页添加标的后会显示在这里")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(portfolio.holdings.enumerated()), id: \.element.id) { index, holding in
                        holdingRow(holding)

                        if index < portfolio.holdings.count - 1 {
                            Divider()
                                .background(AppColors.dividerColor)
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
            }
        }
    }

    private func holdingRow(_ holding: Holding) -> some View {
        HStack(spacing: 12) {
            // 资产类型图标
            ZStack {
                Circle()
                    .fill(holding.assetTypeEnum.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: holding.assetTypeEnum.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(holding.assetTypeEnum.color)
            }

            // 信息
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(holding.symbol)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)

                    Text("·")
                        .foregroundStyle(AppColors.textTertiary.opacity(0.5))

                    Text(holding.marketEnum.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            Spacer()

            // 数量
            VStack(alignment: .trailing, spacing: 2) {
                Text(holding.totalQuantity.formattedQuantity)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppColors.textPrimary)

                Text("\(holding.transactions.count) 笔交易")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textTertiary)
            }

            // 删除按钮
            Button {
                holdingToDelete = holding
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.loss.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - 危险区域

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("危险操作", icon: "exclamationmark.triangle.fill")

            Button {
                deleteAccount()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppColors.loss)
                            .frame(width: 32, height: 32)

                        Image(systemName: "trash.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("删除账户")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppColors.loss)

                        Text("将永久删除该账户及所有数据")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - 辅助组件

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.profit)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - 操作

    private func deleteAccount() {
        modelContext.delete(portfolio)
        // 通知日历视图刷新
        NotificationCenter.default.post(name: .portfolioDataDidChange, object: nil)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AccountManageView(portfolio: Portfolio(name: "楽天証券"))
    }
    .modelContainer(for: Portfolio.self, inMemory: true)
    .preferredColorScheme(.dark)
}
