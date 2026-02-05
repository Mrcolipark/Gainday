import Foundation

extension Double {
    func currencyFormatted(code: String = "JPY", compact: Bool = false, showSign: Bool = false) -> String {
        // Compact format for large numbers
        if compact {
            let absValue = abs(self)
            if absValue >= 1_000_000_000 {
                return "\(Int(absValue / 1_000_000_000))B"
            } else if absValue >= 1_000_000 {
                return "\(Int(absValue / 1_000_000))M"
            } else if absValue >= 1_000 {
                return "\(Int(absValue / 1_000))K"
            }
        }

        let formatted = self.formatted(
            .currency(code: code)
            .precision(.fractionLength(code == "JPY" ? 0 : 2))
        )
        if showSign && self > 0 {
            return "+\(formatted)"
        }
        return formatted
    }

    func percentFormatted(showSign: Bool = true) -> String {
        let sign = showSign && self > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", self))%"
    }

    func compactFormatted(code: String = "JPY", showSign: Bool = false) -> String {
        let absValue = abs(self)
        let sign: String
        if self < 0 {
            sign = "-"
        } else if showSign && self > 0 {
            sign = "+"
        } else {
            sign = ""
        }
        let currencySymbol: String
        switch code {
        case "JPY": currencySymbol = "¥"
        case "CNY": currencySymbol = "¥"
        case "USD": currencySymbol = "$"
        case "HKD": currencySymbol = "HK$"
        default: currencySymbol = code
        }

        if absValue >= 100_000_000 {
            return "\(sign)\(currencySymbol)\(String(format: "%.1f", absValue / 100_000_000))亿"
        } else if absValue >= 10_000 {
            return "\(sign)\(currencySymbol)\(String(format: "%.1f", absValue / 10_000))万"
        } else {
            return "\(sign)\(currencySymbol)\(String(format: "%.0f", absValue))"
        }
    }

    /// 紧凑货币格式 - 用于UI显示，避免换行
    func compactCurrencyFormatted(code: String = "JPY", showSign: Bool = false) -> String {
        let absValue = abs(self)
        let sign: String
        if self < 0 {
            sign = "-"
        } else if showSign && self > 0 {
            sign = "+"
        } else {
            sign = ""
        }

        let currencySymbol: String
        let decimals: Int
        switch code {
        case "JPY":
            currencySymbol = "¥"
            decimals = 0
        case "CNY":
            currencySymbol = "¥"
            decimals = 2
        case "USD":
            currencySymbol = "$"
            decimals = 2
        case "HKD":
            currencySymbol = "HK$"
            decimals = 2
        default:
            currencySymbol = ""
            decimals = 2
        }

        // 对于日元等大数字，使用万/亿单位
        if code == "JPY" || code == "CNY" {
            if absValue >= 100_000_000 {
                return "\(sign)\(currencySymbol)\(String(format: "%.1f", absValue / 100_000_000))亿"
            } else if absValue >= 10_000_000 {
                return "\(sign)\(currencySymbol)\(String(format: "%.0f", absValue / 10_000))万"
            } else if absValue >= 1_000_000 {
                return "\(sign)\(currencySymbol)\(String(format: "%.1f", absValue / 10_000))万"
            }
        }

        // 标准格式
        if decimals == 0 {
            return "\(sign)\(currencySymbol)\(Int(absValue).formatted())"
        } else {
            return "\(sign)\(currencySymbol)\(String(format: "%.\(decimals)f", absValue))"
        }
    }

    var formattedQuantity: String {
        if self == floor(self) {
            return String(format: "%.0f", self)
        }
        return String(format: "%.4f", self).replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
    }
}
