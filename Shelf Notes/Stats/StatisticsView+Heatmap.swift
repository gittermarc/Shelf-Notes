import Foundation

extension StatisticsView {

    func heatmapHintText(range: StatisticsHeatmapRange) -> String {
        switch activityMetric {
        case .readingDays:
            return "„Lesetage“ zählt pro Tag, an dem ein Buch aktiv war (aus readFrom/readTo; bei „Lese ich“ bis heute). Zeitraum: \(range.start.formatted(date: .numeric, time: .omitted))–\(range.end.formatted(date: .numeric, time: .omitted))."
        case .readingMinutes:
            return "„Leseminuten“ summiert die Dauer aller geloggten Lesesessions pro Tag (aus ReadingSession.durationSeconds). Zeitraum: \(range.start.formatted(date: .numeric, time: .omitted))–\(range.end.formatted(date: .numeric, time: .omitted))."
        case .completions:
            return "„Abschlüsse“ zählt pro Tag, an dem ein Buch beendet wurde (readTo/readFrom). Zeitraum: \(range.start.formatted(date: .numeric, time: .omitted))–\(range.end.formatted(date: .numeric, time: .omitted))."
        }
    }

    func heatmapRangeForSelectedYear() -> StatisticsHeatmapRange {
        heatmapRange(for: selectedYear)
    }

    func heatmapRange(for year: Int) -> StatisticsHeatmapRange {
        StatisticsHeatmapBuilder(now: Date(), calendar: Calendar.current).makeRange(for: year)
    }

}
