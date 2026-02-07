import SwiftUI

/// NISA 徽章
struct NISABadge: View {
    let accountType: AccountType

    var body: some View {
        Text(accountType.shortName)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(accountType.color)
            )
    }
}

#Preview {
    HStack(spacing: 12) {
        NISABadge(accountType: .nisa_tsumitate)
        NISABadge(accountType: .nisa_growth)
    }
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
