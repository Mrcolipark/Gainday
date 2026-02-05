import SwiftUI

extension Color {
    static func pnlColor(percent: Double) -> Color {
        AppColors.pnlColor(percent: percent)
    }

    static func pnlForeground(value: Double) -> Color {
        AppColors.pnlForeground(value: value)
    }
}

extension ShapeStyle where Self == Color {
    static var profit: Color { AppColors.profit }
    static var loss: Color { AppColors.loss }
}
