import Foundation

extension StatisticsView {

    func heatmapHintText(range: StatisticsHeatmapRange) -> String {
        switch activityMetric {
        case .readingDays:
            return "„Lesetage“ zählt Tage mit einer echten geloggten Lesesession. Reine Provider-Fortschrittsimporte zählen nicht. Zeitraum: \(range.start.formatted(date: .numeric, time: .omitted))–\(range.end.formatted(date: .numeric, time: .omitted))."
        case .readingMinutes:
            return "„Leseminuten“ summiert die Dauer echter geloggter Lesesessions. Reine Provider-Fortschrittsimporte erzeugen keine Lesezeit. Zeitraum: \(range.start.formatted(date: .numeric, time: .omitted))–\(range.end.formatted(date: .numeric, time: .omitted))."
        case .completions:
            return "„Abschlüsse“ zählt beendete Lesedurchgänge. Wiederholungslesungen bleiben als eigene historische Abschlüsse erhalten. Zeitraum: \(range.start.formatted(date: .numeric, time: .omitted))–\(range.end.formatted(date: .numeric, time: .omitted))."
        }
    }

    func heatmapRangeForSelectedYear() -> StatisticsHeatmapRange {
        heatmapRange(for: selectedYear)
    }

    func heatmapRange(for year: Int) -> StatisticsHeatmapRange {
        StatisticsHeatmapBuilder(now: Date(), calendar: Calendar.current).makeRange(for: year)
    }

}
