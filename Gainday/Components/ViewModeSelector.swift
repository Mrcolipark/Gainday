import SwiftUI

/// iPhone 风格的分段选择器
struct ViewModeSelector: View {
    @Binding var selectedMode: PortfolioDisplayMode
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PortfolioDisplayMode.allCases) { mode in
                modeButton(mode)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.cardSurface)
        )
    }

    private func modeButton(_ mode: PortfolioDisplayMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMode = mode
            }
        } label: {
            Text(mode.localizedName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selectedMode == mode ? AppColors.textPrimary : AppColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background {
                    if selectedMode == mode {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppColors.elevatedSurface)
                            .matchedGeometryEffect(id: "selector", in: animation)
                    }
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectedMode)
    }
}

// 扩展：添加本地化名称
extension PortfolioDisplayMode {
    var localizedName: String {
        switch self {
        case .basic:    return "列表"
        case .details:  return "详情"
        case .holdings: return "持仓"
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        ViewModeSelector(selectedMode: .constant(.basic))
        ViewModeSelector(selectedMode: .constant(.details))
        ViewModeSelector(selectedMode: .constant(.holdings))
    }
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
