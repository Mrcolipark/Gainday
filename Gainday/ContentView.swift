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
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView()
            }

            Tab("Calendar", systemImage: "calendar", value: 1) {
                PnLCalendarView()
            }

            Tab("Markets", systemImage: "chart.line.uptrend.xyaxis", value: 2) {
                MarketsView()
            }

            Tab("News", systemImage: "newspaper.fill", value: 3) {
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
