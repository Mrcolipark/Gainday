//
//  ContentView.swift
//  Gainday
//
//  Created by yanmengru on 2026/02/04.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var languageManager = LanguageManager.shared
    @State private var refreshID = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("首页".localized, systemImage: "house.fill", value: 0) {
                HomeView()
            }

            Tab("日历".localized, systemImage: "calendar", value: 1) {
                PnLCalendarView()
            }

            Tab("市场".localized, systemImage: "chart.line.uptrend.xyaxis", value: 2) {
                MarketsView()
            }

            Tab("资讯".localized, systemImage: "newspaper.fill", value: 3) {
                NewsView()
            }
        }
        .id(refreshID)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            refreshID = UUID()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Portfolio.self,
            Holding.self,
            Transaction.self,
            DailySnapshot.self,
            PriceCache.self
        ], inMemory: true)
}
