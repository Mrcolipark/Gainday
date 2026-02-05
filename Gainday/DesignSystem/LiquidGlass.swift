import SwiftUI

// MARK: - Card Modifier (iPhone Stocks App Style)

/// 简洁的卡片样式 - 仿 iPhone 股票 App
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var tint: Color = .clear

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), tint != .clear {
            content
                .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
        } else {
            // 简洁的深灰色卡片背景 - iPhone 股票 App 风格
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppColors.cardSurface)
                )
        }
    }
}

// MARK: - Liquid Glass Card

struct LiquidGlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let tint: Color
    let content: Content

    init(
        cornerRadius: CGFloat = 20,
        tint: Color = .clear,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(LiquidGlassModifier(cornerRadius: cornerRadius, tint: tint))
    }
}

// MARK: - Simple Button Style

struct GlassButtonStyle: ButtonStyle {
    var tint: Color = .clear

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(AppColors.elevatedSurface)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Simple Chip

struct GlassChip: View {
    let text: String
    var icon: String?
    var tint: Color = .white

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(AppColors.elevatedSurface)
        )
    }
}

// MARK: - View Extension

extension View {
    func liquidGlass(cornerRadius: CGFloat = 20, tint: Color = .clear) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, tint: tint))
    }

    @ViewBuilder
    func liquidGlassCapsule(tint: Color = .clear) -> some View {
        if #available(iOS 26.0, *) {
            if tint == .clear {
                self.glassEffect(.regular, in: .capsule)
            } else {
                self.glassEffect(.regular.tint(tint), in: .capsule)
            }
        } else {
            self.background(AppColors.elevatedSurface, in: Capsule())
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Liquid Glass Card")
                        .font(.headline)
                    Text("iOS 26 native glass effect")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            LiquidGlassCard(tint: .blue) {
                Text("Tinted Glass Card")
                    .font(.headline)
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                GlassChip(text: "盘前", icon: "sun.rise", tint: .orange)
                GlassChip(text: "交易中", tint: .green)
                GlassChip(text: "盘后", tint: .purple)
            }

            Button("Glass Button") {}
                .buttonStyle(GlassButtonStyle(tint: .blue))
        }
    }
    .preferredColorScheme(.dark)
}
