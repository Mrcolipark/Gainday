//
//  GaindayminiBundle.swift
//  Gaindaymini
//
//  Created by yanmengru on 2026/02/06.
//

import WidgetKit
import SwiftUI

@main
struct GaindayminiBundle: WidgetBundle {
    var body: some Widget {
        DailyPnLWidget()
        WatchlistWidget()
        MonthHeatmapWidget()
    }
}
