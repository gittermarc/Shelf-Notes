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

    struct HeatmapRange {
        let start: Date           // startOfDay
        let end: Date             // startOfDay, inclusive
        let gridStart: Date       // Monday startOfDay
        let gridEnd: Date         // Sunday startOfDay
    }

    func heatmapRangeForSelectedYear() -> HeatmapRange {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current

        let start = cal.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? Date.distantPast
        let startDay = cal.startOfDay(for: start)

        let endExclusive = cal.date(from: DateComponents(year: selectedYear + 1, month: 1, day: 1)) ?? Date.distantFuture
        let endOfYear = cal.date(byAdding: .day, value: -1, to: endExclusive) ?? Date.distantFuture
        let today = cal.startOfDay(for: Date())

        let endDay: Date
        if cal.component(.year, from: today) == selectedYear {
            endDay = min(today, cal.startOfDay(for: endOfYear))
        } else {
            endDay = cal.startOfDay(for: endOfYear)
        }

        let gridStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDay)) ?? startDay
        let endWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: endDay)) ?? endDay
        let gridEnd = cal.date(byAdding: .day, value: 6, to: endWeekStart) ?? endDay

        return HeatmapRange(start: startDay, end: endDay, gridStart: gridStart, gridEnd: gridEnd)
    }

    struct HeatmapDay: Identifiable {
        let id: Date
        let date: Date
        let count: Int
        let level: Int
        let isInRange: Bool
    }

    struct HeatmapWeek: Identifiable {
        let id: Int
        let days: [HeatmapDay]
    }

    func activityDailyCounts(metric: ActivityMetric, range: HeatmapRange) -> [Date: Int] {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current

        var counts: [Date: Int] = [:]

        func addDay(_ d: Date) {
            let day = cal.startOfDay(for: d)
            guard day >= range.start && day <= range.end else { return }
            counts[day, default: 0] += 1
        }

        func addRange(from: Date, to: Date) {
            var day = cal.startOfDay(for: from)
            let end = cal.startOfDay(for: to)
            guard day <= end else { return }

            while day <= end {
                addDay(day)
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        switch metric {
        case .readingMinutes:
            var secondsByDay: [Date: Int] = [:]

            func addSeconds(_ secs: Int, on dayDate: Date) {
                let day = cal.startOfDay(for: dayDate)
                guard day >= range.start && day <= range.end else { return }
                guard secs > 0 else { return }
                secondsByDay[day, default: 0] += secs
            }

            func addSession(start: Date, end: Date) {
                var start = start
                var end = end
                if end < start { (start, end) = (end, start) }

                // Clamp to heatmap year range (absolute time)
                let clampedStart = max(start, range.start)
                let clampedEnd = min(end, cal.date(byAdding: .day, value: 1, to: range.end) ?? range.end)
                guard clampedEnd > clampedStart else { return }

                var cursor = clampedStart
                while cursor < clampedEnd {
                    let dayStart = cal.startOfDay(for: cursor)
                    guard let nextDayStart = cal.date(byAdding: .day, value: 1, to: dayStart) else { break }
                    let segmentEnd = min(clampedEnd, nextDayStart)
                    let segSecs = max(0, Int(segmentEnd.timeIntervalSince(cursor).rounded(.down)))
                    addSeconds(segSecs, on: dayStart)
                    cursor = segmentEnd
                }
            }

            for b in scopedBooks {
                for s in b.readingSessionsSafe {
                    addSession(start: s.startedAt, end: s.endedAt)
                }
            }

            var minutes: [Date: Int] = [:]
            minutes.reserveCapacity(secondsByDay.count)
            for (day, secs) in secondsByDay {
                let m = Int((Double(secs) / 60.0).rounded())
                if m > 0 { minutes[day] = m }
            }
            return minutes

        case .completions:
            for b in scopedBooks where b.status == .finished {
                if let d = b.readTo ?? b.readFrom {
                    addDay(d)
                }
            }

        case .readingDays:
            for b in scopedBooks {
                switch b.status {
                case .finished:
                    if let from = b.readFrom, let to = b.readTo {
                        addRange(from: from, to: to)
                    } else if let d = b.readTo ?? b.readFrom {
                        addDay(d)
                    }

                case .reading:
                    if let from = b.readFrom {
                        let to = min(range.end, cal.startOfDay(for: Date()))
                        addRange(from: from, to: to)
                    }

                case .toRead:
                    break
                }
            }
        }

        return counts
    }

    func heatLevel(count: Int, maxCount: Int) -> Int {
        guard count > 0 else { return 0 }
        guard maxCount > 0 else { return 0 }

        if maxCount <= 4 {
            return min(count, 4)
        }

        let r = Double(count) / Double(maxCount)
        if r <= 0.25 { return 1 }
        if r <= 0.50 { return 2 }
        if r <= 0.75 { return 3 }
        return 4
    }

    func heatmapWeeks(counts: [Date: Int], range: HeatmapRange) -> [HeatmapWeek] {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current

        let days = cal.dateComponents([.day], from: range.gridStart, to: range.gridEnd).day ?? 0
        let weekCount = max(1, (days / 7) + 1)

        let maxCount = counts.values.max() ?? 0
        var weeks: [HeatmapWeek] = []
        weeks.reserveCapacity(weekCount)

        for w in 0..<weekCount {
            let weekStart = cal.date(byAdding: .day, value: w * 7, to: range.gridStart) ?? range.gridStart
            var weekDays: [HeatmapDay] = []
            weekDays.reserveCapacity(7)

            for d in 0..<7 {
                let date = cal.date(byAdding: .day, value: d, to: weekStart) ?? weekStart
                let day = cal.startOfDay(for: date)

                let inRange = (day >= range.start && day <= range.end)
                let count = inRange ? (counts[day] ?? 0) : 0
                let level = inRange ? heatLevel(count: count, maxCount: maxCount) : 0

                weekDays.append(
                    HeatmapDay(
                        id: day,
                        date: day,
                        count: count,
                        level: level,
                        isInRange: inRange
                    )
                )
            }

            weeks.append(HeatmapWeek(id: w, days: weekDays))
        }

        return weeks
    }

    struct HeatmapStats {
        let activeDays: Int
        let maxCount: Int
        let currentStreak: Int
        let longestStreak: Int
        let bestDayLabel: String
        let bestWeekdayLabel: String
        let bestWeekLabel: String
    }

    func heatmapStats(counts: [Date: Int], range: HeatmapRange, metric: ActivityMetric) -> HeatmapStats {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current

        let maxCount = counts.values.max() ?? 0
        let activeDays = counts.values.filter { $0 > 0 }.count

        let unitSuffix = metric.unitSuffix

        // best day
        var bestDay: Date? = nil
        var bestDayCount: Int = 0
        for (d, c) in counts where c > 0 {
            if c > bestDayCount || (c == bestDayCount && (bestDay == nil || d < bestDay!)) {
                bestDay = d
                bestDayCount = c
            }
        }
        let bestDayLabel: String
        if let bestDay {
            bestDayLabel = "\(bestDay.formatted(date: .abbreviated, time: .omitted)) • \(formatInt(bestDayCount))\(unitSuffix)"
        } else {
            bestDayLabel = "–"
        }

        // weekday sums (Mo..So)
        let weekdayLabels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        var weekdaySums = Array(repeating: 0, count: 7)

        for (d, c) in counts where c > 0 {
            let w = cal.component(.weekday, from: d) // 1=So ... 7=Sa
            let idx = (w + 5) % 7                    // 0=Mo ... 6=So
            weekdaySums[idx] += c
        }

        let bestWeekdayIdx = weekdaySums.enumerated().max(by: { $0.element < $1.element })?.offset
        let bestWeekdayLabel = (bestWeekdayIdx != nil && weekdaySums[bestWeekdayIdx!] > 0)
            ? "\(weekdayLabels[bestWeekdayIdx!]) • \(formatInt(weekdaySums[bestWeekdayIdx!]))\(unitSuffix)"
            : "–"

        // best week (ISO KW)
        var weekSums: [String: Int] = [:]
        for (d, c) in counts where c > 0 {
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
            let y = comps.yearForWeekOfYear ?? selectedYear
            let w = comps.weekOfYear ?? 0
            let key = "\(y)-\(w)"
            weekSums[key, default: 0] += c
        }
        var bestWeekKey: String? = nil
        var bestWeekSum = 0
        for (k, s) in weekSums {
            if s > bestWeekSum {
                bestWeekSum = s
                bestWeekKey = k
            }
        }
        let bestWeekLabel: String
        if let bestWeekKey, bestWeekSum > 0 {
            let parts = bestWeekKey.split(separator: "-")
            let y = parts.first.map(String.init) ?? "\(selectedYear)"
            let w = parts.dropFirst().first.map(String.init) ?? "?"
            bestWeekLabel = "KW \(w) (\(y)) • \(formatInt(bestWeekSum))\(unitSuffix)"
        } else {
            bestWeekLabel = "–"
        }

        func countOn(_ d: Date) -> Int { counts[cal.startOfDay(for: d)] ?? 0 }

        // current streak: from end backwards
        var currentStreak = 0
        var cursor = range.end
        while cursor >= range.start && countOn(cursor) > 0 {
            currentStreak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        // longest streak: scan forward
        var longestStreak = 0
        var running = 0
        var day = range.start
        while day <= range.end {
            if countOn(day) > 0 {
                running += 1
                longestStreak = max(longestStreak, running)
            } else {
                running = 0
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return HeatmapStats(
            activeDays: activeDays,
            maxCount: maxCount,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            bestDayLabel: bestDayLabel,
            bestWeekdayLabel: bestWeekdayLabel,
            bestWeekLabel: bestWeekLabel
        )
    }

}
