import SwiftUI

/// 语言管理器 - 管理应用语言切换
@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    /// 当前语言设置: "system", "zh-Hans", "en", "ja"
    var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: "appLanguage")
        }
    }

    /// 返回对应的 Locale，nil 表示跟随系统
    var locale: Locale? {
        switch language {
        case "zh-Hans": return Locale(identifier: "zh-Hans")
        case "zh-Hant": return Locale(identifier: "zh-Hant")
        case "en": return Locale(identifier: "en")
        case "ja": return Locale(identifier: "ja")
        default: return nil  // 跟随系统
        }
    }

    /// 当前语言显示名称
    var displayName: String {
        switch language {
        case "zh-Hans": return "简体中文"
        case "zh-Hant": return "繁體中文"
        case "en": return "English"
        case "ja": return "日本語"
        default: return "跟随系统"
        }
    }

    private init() {
        self.language = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
    }
}
