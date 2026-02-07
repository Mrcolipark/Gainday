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
    @State private var appearanceManager = AppearanceManager.shared
    @State private var languageManager = LanguageManager.shared

    init() {
        configureAppearance()
    }

    /// App Group identifier for sharing data with widgets
    private static let appGroupIdentifier = "group.com.gainday.shared"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Portfolio.self,
            Holding.self,
            Transaction.self,
            DailySnapshot.self,
            PriceCache.self
        ])

        // 使用 App Group 共享目录存储数据库，以便 Widget 访问
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(appGroupIdentifier),
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
                .preferredColorScheme(appearanceManager.colorScheme)
                .environment(\.locale, languageManager.locale ?? .current)
                .withErrorPresenter()
                .onAppear {
                    appearanceManager.applyAppearance()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func configureAppearance() {
        // TabBar tint color
        UITabBar.appearance().tintColor = UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1)

        // TableView 背景
        UITableView.appearance().backgroundColor = .clear

        // 下拉刷新控件颜色
        UIRefreshControl.appearance().tintColor = UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1)

        // 应用初始外观
        AppearanceManager.shared.applyAppearance()
    }
}
