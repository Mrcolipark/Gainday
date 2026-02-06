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

    init() {
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
                .preferredColorScheme(appearanceManager.colorScheme)
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
