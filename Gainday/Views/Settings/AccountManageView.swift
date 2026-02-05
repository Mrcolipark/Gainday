import SwiftUI
import SwiftData

struct AccountManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var portfolio: Portfolio

    @State private var editedName: String = ""
    @State private var editedAccountType: AccountType = .normal
    @State private var editedBaseCurrency: BaseCurrency = .JPY
    @State private var editedColorTag: String = "blue"

    var body: some View {
        Form {
            Section("账户信息") {
                TextField("账户名称", text: $editedName)
                    .onSubmit {
                        portfolio.name = editedName
                    }

                Picker("账户类型", selection: $editedAccountType) {
                    ForEach(AccountType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .onChange(of: editedAccountType) {
                    portfolio.accountType = editedAccountType.rawValue
                }

                Picker("基准货币", selection: $editedBaseCurrency) {
                    ForEach(BaseCurrency.allCases) { currency in
                        Text(currency.displayName).tag(currency)
                    }
                }
                .onChange(of: editedBaseCurrency) {
                    portfolio.baseCurrency = editedBaseCurrency.rawValue
                }
            }

            Section("标识颜色") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(AppColors.accountTagKeys, id: \.self) { key in
                        Circle()
                            .fill(AppColors.tagColor(key))
                            .frame(width: 36, height: 36)
                            .overlay {
                                if editedColorTag == key {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture {
                                editedColorTag = key
                                portfolio.colorTag = key
                            }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("持仓 (\(portfolio.holdings.count))") {
                ForEach(portfolio.holdings) { holding in
                    HStack {
                        Image(systemName: holding.assetTypeEnum.iconName)
                            .foregroundStyle(holding.assetTypeEnum.color)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(holding.name)
                                .font(.subheadline)
                            Text(holding.symbol)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("×\(holding.totalQuantity.formattedQuantity)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        let holding = portfolio.holdings[index]
                        portfolio.holdings.remove(at: index)
                        modelContext.delete(holding)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    modelContext.delete(portfolio)
                } label: {
                    Label("删除账户", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(portfolio.name)
        .onAppear {
            editedName = portfolio.name
            editedAccountType = portfolio.accountTypeEnum
            editedBaseCurrency = portfolio.baseCurrencyEnum
            editedColorTag = portfolio.colorTag
        }
        .onDisappear {
            portfolio.name = editedName
        }
    }
}

#Preview {
    NavigationStack {
        AccountManageView(portfolio: Portfolio(name: "楽天証券"))
    }
    .modelContainer(for: Portfolio.self, inMemory: true)
}
