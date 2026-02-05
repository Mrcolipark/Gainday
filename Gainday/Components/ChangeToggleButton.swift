import SwiftUI

struct ChangeToggleButton: View {
    @Binding var showPercent: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                showPercent.toggle()
            }
        } label: {
            Text(showPercent ? "%" : "$")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 32, height: 28)
                .background {
                    ZStack {
                        Capsule()
                            .fill(AppColors.elevatedSurface)
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    }
                }
                .contentTransition(.numericText())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: showPercent)
    }
}

#Preview {
    ChangeToggleButton(showPercent: .constant(true))
        .padding()
        .background(AppColors.background)
        .preferredColorScheme(.dark)
}
