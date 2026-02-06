import SwiftUI

enum AppColors {
    // MARK: - iPhone Stocks App Style Colors

    /// 盈利色 - iOS 系统绿
    static let profit = Color(hex: 0x34C759)
    /// 亏损色 - iOS 系统红
    static let loss = Color(hex: 0xFF3B30)
    /// 中性色 - 系统灰
    static let neutral = Color(hex: 0x8E8E93)

    /// 主色调 - iOS 系统蓝
    static let accent = Color(hex: 0x007AFF)

    // MARK: - Background System (Pure Black for OLED)

    /// 主背景 - 纯黑 (OLED friendly)
    static let background = Color.black
    /// 次级背景 - 深灰卡片
    static let secondaryBackground = Color(hex: 0x1C1C1E)
    /// 三级背景 - 更亮的灰
    static let tertiaryBackground = Color(hex: 0x2C2C2E)

    // MARK: - Surface Colors

    /// 卡片表面
    static let cardSurface = Color(hex: 0x1C1C1E)
    /// 悬浮表面
    static let elevatedSurface = Color(hex: 0x2C2C2E)
    /// 分割线 - 细微的
    static let dividerColor = Color(hex: 0x38383A)
    /// 区块标题
    static let sectionHeader = Color(hex: 0x8E8E93)

    // MARK: - Text Hierarchy (High Contrast)

    /// 主要文字 - 纯白，最高对比度
    static let textPrimary = Color.white
    /// 次要文字 - 系统灰
    static let textSecondary = Color(hex: 0x8E8E93)
    /// 第三级文字 - 更暗的灰
    static let textTertiary = Color(hex: 0x636366)

    // MARK: - 12+ Stop Saturated Heatmap Colors (High Contrast)

    static func pnlColor(percent: Double) -> Color {
        switch percent {
        case ..<(-5):   return Color(hex: 0xB71C1C)   // deep crimson
        case ..<(-3):   return Color(hex: 0xC62828)   // dark red
        case ..<(-2):   return Color(hex: 0xD32F2F)   // crimson
        case ..<(-1):   return Color(hex: 0xE53935)   // red
        case ..<(-0.5): return Color(hex: 0xEF5350)   // coral red
        case ..<0:      return Color(hex: 0xF44336)   // medium red (替代淡粉)
        case 0:         return Color(hex: 0x616161)   // neutral dark gray
        case ..<0.5:    return Color(hex: 0x4CAF50)   // medium green (替代淡绿)
        case ..<1:      return Color(hex: 0x43A047)   // green
        case ..<2:      return Color(hex: 0x388E3C)   // darker green
        case ..<3:      return Color(hex: 0x2E7D32)   // deep green
        case ..<5:      return Color(hex: 0x1B5E20)   // darkest green
        default:        return Color(hex: 0x0D5302)   // ultra deep green
        }
    }

    static func pnlForeground(value: Double) -> Color {
        if value > 0 { return profit }
        if value < 0 { return loss }
        return neutral
    }

    static let accountTags: [String: Color] = [
        "blue":   .blue,
        "orange": .orange,
        "purple": .purple,
        "teal":   .teal,
        "pink":   .pink,
        "indigo": .indigo
    ]

    static let accountTagKeys = ["blue", "orange", "purple", "teal", "pink", "indigo"]

    static func tagColor(_ key: String) -> Color {
        accountTags[key] ?? .blue
    }

    // Share card gradients
    static let shareCardGradient = LinearGradient(
        colors: [Color(white: 0.12), Color(white: 0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }

    /// 根据深色/浅色模式自动切换颜色
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
