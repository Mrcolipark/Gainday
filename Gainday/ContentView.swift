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

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("首页", systemImage: "house.fill", value: 0) {
                HomeView()
            }

            Tab("日历", systemImage: "calendar", value: 1) {
                PnLCalendarView()
            }

            Tab("市场", systemImage: "chart.line.uptrend.xyaxis", value: 2) {
                MarketsView()
            }

            Tab("资讯", systemImage: "newspaper.fill", value: 3) {
                NewsView()
            }
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
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
