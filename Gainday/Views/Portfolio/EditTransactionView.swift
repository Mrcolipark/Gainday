import SwiftUI
import SwiftData
import WidgetKit

/// 编辑交易记录
struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction

    @State private var transactionType: TransactionType
    @State private var quantity: String
    @State private var price: String
    @State private var fee: String
    @State private var date: Date
    @State private var note: String

    init(transaction: Transaction) {
        self.transaction = transaction
        _transactionType = State(initialValue: transaction.transactionType)
        _quantity = State(initialValue: transaction.quantity.formattedQuantity)
        _price = State(initialValue: String(transaction.price))
        _fee = State(initialValue: transaction.fee > 0 ? String(transaction.fee) : "")
        _date = State(initialValue: transaction.date)
        _note = State(initialValue: transaction.note)
    }

    private var holdingName: String {
        transaction.holding?.name ?? ""
    }

    private var holdingSymbol: String {
        transaction.holding?.symbol ?? ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 标的信息（只读）
                    holdingInfoSection

                    // 交易类型
                    transactionTypeSection

                    // 交易详情
                    transactionDetailsSection

                    // 验证提示
                    if let message = validationMessage {
                        validationBanner(message)
                    }

                    Spacer(minLength: 100)
                }
                .padding(16)
            }
            .background(AppColors.background)
            .safeAreaInset(edge: .bottom) {
                saveButtonBar
            }
            .navigationTitle("编辑交易".localized)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消".localized) { dismiss() }
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
    }

    // MARK: - 标的信息（只读）

    private var holdingInfoSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(holdingSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(holdingName)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    // MARK: - 交易类型

    private var transactionTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("交易类型".localized)

            HStack(spacing: 0) {
                ForEach(TransactionType.allCases.map { $0 }) { type in
                    Button {
                        transactionType = type
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 20))
                            Text(type.displayName)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(transactionType == type ? .white : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(transactionType == type ? typeColor(type) : Color.clear)
                        )
                    }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    private func typeColor(_ type: TransactionType) -> Color {
        switch type {
        case .buy: return AppColors.profit
        case .sell: return AppColors.loss
        case .dividend: return .blue
        }
    }

    // MARK: - 交易详情

    private var transactionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("交易详情".localized)

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    FormField(
                        label: "数量".localized,
                        placeholder: "0",
                        text: $quantity,
                        suffix: "股".localized,
                        keyboardType: .decimalPad
                    )

                    FormField(
                        label: "价格".localized,
                        placeholder: "0",
                        text: $price,
                        suffix: transaction.currency,
                        keyboardType: .decimalPad
                    )
                }

                FormField(
                    label: "手续费".localized,
                    placeholder: "0",
                    text: $fee,
                    suffix: transaction.currency,
                    keyboardType: .decimalPad
                )

                // 日期
                VStack(alignment: .leading, spacing: 8) {
                    Text("日期".localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(AppColors.profit)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppColors.elevatedSurface)
                        )
                }

                FormField(
                    label: "备注".localized,
                    placeholder: "可选".localized,
                    text: $note
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.cardSurface)
            )
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        guard let qty = Double(quantity), qty > 0,
              let prc = Double(price), prc > 0 else { return false }
        if date > Date() { return false }
        guard prc >= 0.0001 && prc <= 1_000_000_000 else { return false }
        return true
    }

    private var validationMessage: String? {
        if date > Date() {
            return "交易日期不能是未来日期".localized
        }
        if let prc = Double(price), prc > 1_000_000_000 {
            return "价格超出合理范围".localized
        }
        return nil
    }

    private func validationBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.orange.opacity(0.15))
        )
    }

    // MARK: - 保存按钮

    private var saveButtonBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.dividerColor)

            Button {
                saveChanges()
            } label: {
                Text("保存".localized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isValid ? AppColors.profit : AppColors.textTertiary)
                    )
            }
            .disabled(!isValid)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppColors.cardSurface)
    }

    // MARK: - 辅助组件

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColors.textPrimary)
    }

    // MARK: - Save

    private func saveChanges() {
        guard let qty = Double(quantity),
              let prc = Double(price) else { return }

        transaction.type = transactionType.rawValue
        transaction.quantity = qty
        transaction.price = prc
        transaction.fee = Double(fee) ?? 0
        transaction.date = date
        transaction.note = note

        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .portfolioDataDidChange, object: nil)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            ErrorPresenter.shared.showError(error)
        }

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        dismiss()
    }
}

// MARK: - 表单输入组件（复用 AddTransactionView 中定义的 FormField）

#Preview {
    EditTransactionView(
        transaction: Transaction(
            type: TransactionType.buy.rawValue,
            date: Date(),
            quantity: 100,
            price: 150.0,
            fee: 0,
            currency: "USD"
        )
    )
    .modelContainer(for: Transaction.self, inMemory: true)
    .preferredColorScheme(.dark)
}
