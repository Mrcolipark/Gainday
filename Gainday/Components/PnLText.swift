import SwiftUI

/// 极简风格的盈亏金额文字
struct PnLText: View {
    let value: Double
    let currencyCode: String
    let showSign: Bool
    let style: PnLTextStyle

    enum PnLTextStyle {
        case large
        case medium
        case small
        case caption
    }

    init(_ value: Double, currencyCode: String = "JPY", showSign: Bool = true, style: PnLTextStyle = .medium) {
        self.value = value
        self.currencyCode = currencyCode
        self.showSign = showSign
        self.style = style
    }

    var body: some View {
        Text(formattedValue)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(AppColors.pnlForeground(value: value))
            .contentTransition(.numericText(value: value))
            .animation(.snappy, value: value)
    }

    private var font: Font {
        switch style {
        case .large:   return AppFonts.largeAmount
        case .medium:  return AppFonts.mediumAmount
        case .small:   return AppFonts.smallAmount
        case .caption: return .system(size: 12, weight: .medium, design: .rounded)
        }
    }

    private var formattedValue: String {
        let formatted = value.formatted(.currency(code: currencyCode)
            .precision(.fractionLength(currencyCode == "JPY" ? 0 : 2)))
        if showSign && value > 0 {
            return "+\(formatted)"
        }
        return formatted
    }
}

/// 极简风格的盈亏百分比文字 - 纯文字，无背景
struct PnLPercentText: View {
    let value: Double
    let style: PnLText.PnLTextStyle
    let showArrow: Bool

    init(_ value: Double, style: PnLText.PnLTextStyle = .small, showArrow: Bool = true) {
        self.value = value
        self.style = style
        self.showArrow = showArrow
    }

    private var pnlColor: Color {
        AppColors.pnlForeground(value: value)
    }

    var body: some View {
        HStack(spacing: 3) {
            if showArrow {
                Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: iconSize, weight: .semibold))
            }
            Text(formattedPercent)
                .font(font)
                .monospacedDigit()
        }
        .foregroundStyle(pnlColor)
        .contentTransition(.numericText(value: value))
        .animation(.snappy, value: value)
    }

    private var iconSize: CGFloat {
        switch style {
        case .large: return 14
        case .medium: return 12
        case .small: return 10
        case .caption: return 8
        }
    }

    private var font: Font {
        switch style {
        case .large:   return AppFonts.largeAmount
        case .medium:  return AppFonts.mediumAmount
        case .small:   return AppFonts.smallAmount
        case .caption: return .system(size: 11, weight: .medium, design: .rounded)
        }
    }

    private var formattedPercent: String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("PnLText").font(.caption).foregroundStyle(.secondary)
                PnLText(12340, currencyCode: "JPY", style: .large)
                PnLText(-5600, currencyCode: "JPY", style: .medium)
                PnLText(1234.56, currencyCode: "USD", style: .small)
            }

            Divider()

            VStack(spacing: 8) {
                Text("PnLPercentText").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    PnLPercentText(2.34, style: .large)
                    PnLPercentText(-1.56, style: .large)
                }
                HStack(spacing: 16) {
                    PnLPercentText(2.34, style: .small)
                    PnLPercentText(-1.56, style: .small)
                }
                HStack(spacing: 16) {
                    PnLPercentText(2.34, style: .caption, showArrow: false)
                    PnLPercentText(-1.56, style: .caption, showArrow: false)
                }
            }
        }
        .padding()
    }
}
