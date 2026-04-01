import Foundation

extension StatisticsView {

    func heatmapHintText(range: HeatmapRange) -> String {
        switch activityMetric {
        case .readingDays:
            return "„Lesetage“ zählt pro Tag, an dem ein Buch aktiv war (aus readFrom/readTo; bei „Lese ich“ bis heute). Zeitraum: \(range.start.formatted(date: .numeric, time: .omitted))–\(range.end.formatted(date: .numeric, time: .omitted))."
        case .readingMinutes:
            return "„Leseminuten“ summiert die Dauer aller geloggten Lesesessions pro Tag (aus ReadingSession.durationSeconds). Zeitraum: \(range.start.formatted(date: .numeric, time: .omitted))–\(range.end.formatted(date: .numeric, time: .omitted))."
        case .completions:
            return "„Abschlüsse“ zählt pro Tag, an dem ein Buch beendet wurde (readTo/readFrom). Zeitraum: \(range.start.formatted(date: .numeric, time: .omitted))–\(range.end.formatted(date: .numeric, time: .omitted))."
        }
    }

    struct HeatmapRange: Sendable {
        let start: Date
        let end: Date
        let gridStart: Date
        let gridEnd: Date
    }

    func heatmapRangeForSelectedYear() -> HeatmapRange {
        heatmapRange(for: selectedYear)
    }

    func heatmapRange(for year: Int) -> HeatmapRange {
        StatisticsHeatmapBuilder(now: Date(), calendar: Calendar.current).makeRange(for: year)
    }

    struct HeatmapDay: Identifiable, Sendable {
        let id: Date
        let date: Date
        let count: Int
        let level: Int
        let isInRange: Bool
    }

    struct HeatmapWeek: Identifiable, Sendable {
        let id: Int
        let days: [HeatmapDay]
    }

    struct HeatmapStats: Sendable {
        let activeDays: Int
        let maxCount: Int
        let currentStreak: Int
        let longestStreak: Int
        let bestDayLabel: String
        let bestWeekdayLabel: String
        let bestWeekLabel: String
    }
}
