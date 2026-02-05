import WidgetKit
import SwiftUI

@main
struct GainDayWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyPnLWidget()
        WeekCalendarWidget()
        MonthCalendarWidget()
    }
}
