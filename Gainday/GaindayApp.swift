//
//  GaindayApp.swift
//  Gainday
//
//  Created by yanmengru on 2026/02/04.
//

import SwiftUI
import SwiftData

@main
struct GaindayApp: App {
    @AppStorage("appearance") private var appearance = "system"

    init() {
        // 配置全局深色外观
        configureAppearance()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Portfolio.self,
            Holding.self,
            Transaction.self,
            DailySnapshot.self,
            PriceCache.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)  // 强制深色模式
                .withErrorPresenter()
                .onAppear {
                    // 设置 window 的界面风格
                    setWindowInterfaceStyle(.dark)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func setWindowInterfaceStyle(_ style: UIUserInterfaceStyle) {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }

    private func configureAppearance() {
        // 液态玻璃风格 - 透明背景

        // 设置导航栏外观 - 透明/玻璃效果
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        navAppearance.backgroundColor = .clear
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = .white

        // 设置 TabBar 外观 - 玻璃效果
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tabAppearance.backgroundColor = .clear
        tabAppearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1) // iOS 蓝

        // 设置 TableView/List 背景
        UITableView.appearance().backgroundColor = .clear

        // 下拉刷新控件颜色 - 绿色
        UIRefreshControl.appearance().tintColor = UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1)
    }
}
