import SwiftUI

/// 外观管理器 - 管理应用主题切换
@Observable
final class AppearanceManager {
    static let shared = AppearanceManager()

    var appearance: String {
        didSet {
            UserDefaults.standard.set(appearance, forKey: "appearance")
            applyAppearance()
        }
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private init() {
        self.appearance = UserDefaults.standard.string(forKey: "appearance") ?? "system"
    }

    func applyAppearance() {
        DispatchQueue.main.async {
            let style: UIUserInterfaceStyle
            switch self.appearance {
            case "light": style = .light
            case "dark": style = .dark
            default: style = .unspecified
            }

            // 更新所有 window 的样式
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        window.overrideUserInterfaceStyle = style
                    }
                }
            }

            // 更新导航栏和 TabBar 外观
            self.updateBarAppearances()
        }
    }

    private func updateBarAppearances() {
        let isDark: Bool
        switch appearance {
        case "light":
            isDark = false
        case "dark":
            isDark = true
        default:
            isDark = UITraitCollection.current.userInterfaceStyle == .dark
        }

        // 导航栏
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: isDark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
        navAppearance.backgroundColor = .clear
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [.foregroundColor: isDark ? UIColor.white : UIColor.black]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: isDark ? UIColor.white : UIColor.black]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = isDark ? .white : .black

        // TabBar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: isDark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
        tabAppearance.backgroundColor = .clear
        tabAppearance.shadowColor = .clear

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
