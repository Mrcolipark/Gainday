import SwiftUI

/// 极简风格的玻璃卡片
struct GlassCard<Content: View>: View {
    let content: Content
    var tint: Color

    init(
        tint: Color = .clear,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 20, tint: tint)
    }
}

/// 带颜色的玻璃卡片
struct AccentGlassCard<Content: View>: View {
    let color: Color
    let content: Content

    init(color: Color = .blue, @ViewBuilder content: () -> Content) {
        self.color = color
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 20, tint: color.opacity(0.3))
    }
}

/// 玻璃胶囊
struct GlassPill<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .liquidGlassCapsule()
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Assets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("¥1,234,567")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                }
            }

            AccentGlassCard(color: .green) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's P&L")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("+¥12,340")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.green)
                }
            }

            GlassPill {
                Label("Trading", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
    }
}
