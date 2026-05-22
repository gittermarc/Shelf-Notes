import SwiftUI

extension StatisticsView {

    func fallbackMonthsCount(for year: Int) -> Int {
        StatisticsMonthAxisBuilder
            .months(for: year, now: Date(), calendar: Calendar.current)
            .count
    }
}
