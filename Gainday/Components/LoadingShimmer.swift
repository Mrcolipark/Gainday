import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -200

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.25),
                        .white.opacity(0.4),
                        .white.opacity(0.25),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 200)
                .offset(x: phase)
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.8)
                        .repeatForever(autoreverses: false)
                    ) {
                        phase = 400
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct LoadingShimmer: View {
    var height: CGFloat = 20
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color.secondary.opacity(0.1),
                        Color.secondary.opacity(0.15),
                        Color.secondary.opacity(0.1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: height)
            .modifier(ShimmerModifier())
    }
}

struct LoadingCardShimmer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LoadingShimmer(height: 12, cornerRadius: 4)
                .frame(width: 80)
            LoadingShimmer(height: 28, cornerRadius: 6)
                .frame(width: 180)
            HStack(spacing: 12) {
                LoadingShimmer(height: 12, cornerRadius: 4)
                    .frame(width: 60)
                LoadingShimmer(height: 12, cornerRadius: 4)
                    .frame(width: 50)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.08), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            }
        }
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.05).ignoresSafeArea()
        VStack(spacing: 16) {
            LoadingShimmer()
            LoadingShimmer(height: 40)
            LoadingCardShimmer()
        }
        .padding()
    }
}
