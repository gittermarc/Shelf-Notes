import Foundation

nonisolated struct StatisticsHeatmapBuilder {
    let now: Date
    let calendar: Calendar

    init(now: Date = Date(), calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    func makeHeatmapCache(
        for key: StatisticsHeatmapCacheKey,
        books: [StatisticsBookSnapshot],
        sessionBooks: [StatisticsSessionBookSnapshot] = []
    ) -> StatisticsHeatmapCache {
        let scoped = scopedBooks(for: key.scope, in: books)
        let scopedSessionBooks: [StatisticsSessionBookSnapshot]
        if key.activityMetric == .readingMinutes {
            scopedSessionBooks = self.scopedSessionBooks(
                for: key.scope,
                books: books,
                sessionBooks: sessionBooks
            )
        } else {
            scopedSessionBooks = []
        }
        let range = heatmapRange(for: key.selectedYear)
        let counts = activityDailyCounts(
            metric: key.activityMetric,
            range: range,
            books: scoped,
            sessionBooks: scopedSessionBooks
        )
        let stats = heatmapStats(
            counts: counts,
            range: range,
            metric: key.activityMetric,
            fallbackYear: key.selectedYear
        )
        let weeks = heatmapWeeks(counts: counts, range: range)

        return StatisticsHeatmapCache(
            key: key,
            range: range,
            counts: counts,
            stats: stats,
            weeks: weeks
        )
    }
}

nonisolated extension StatisticsHeatmapBuilder {
    func makeRange(for year: Int) -> StatisticsHeatmapRange {
        heatmapRange(for: year)
    }
}

private nonisolated extension StatisticsHeatmapBuilder {
    func scopedBooks(
        for scope: StatisticsScope,
        in input: [StatisticsBookSnapshot]
    ) -> [StatisticsBookSnapshot] {
        switch scope {
        case .all:
            return input
        case .finished:
            return input.filter { $0.status == .finished || $0.hasCompletedReading }
        case .reading:
            return input.filter { $0.status == .reading }
        case .toRead:
            return input.filter { $0.status == .toRead }
        }
    }

    func scopedSessionBooks(
        for scope: StatisticsScope,
        books: [StatisticsBookSnapshot],
        sessionBooks: [StatisticsSessionBookSnapshot]
    ) -> [StatisticsSessionBookSnapshot] {
        let source = sessionBooks.isEmpty
            ? books.map { StatisticsSessionBookSnapshot(bookSnapshot: $0) }
            : sessionBooks

        switch scope {
        case .all:
            return source
        case .finished:
            return source.filter { $0.status == .finished || $0.hasCompletedReading }
        case .reading:
            return source.filter { $0.status == .reading }
        case .toRead:
            return source.filter { $0.status == .toRead }
        }
    }

    func heatmapRange(for year: Int) -> StatisticsHeatmapRange {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = self.calendar.timeZone

        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .distantPast
        let startDay = calendar.startOfDay(for: start)

        let endExclusive = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? .distantFuture
        let endOfYear = calendar.date(byAdding: .day, value: -1, to: endExclusive) ?? .distantFuture
        let today = calendar.startOfDay(for: now)

        let endDay: Date
        if calendar.component(.year, from: today) == year {
            endDay = min(today, calendar.startOfDay(for: endOfYear))
        } else {
            endDay = calendar.startOfDay(for: endOfYear)
        }

        let gridStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDay)
        ) ?? startDay
        let endWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: endDay)
        ) ?? endDay
        let gridEnd = calendar.date(byAdding: .day, value: 6, to: endWeekStart) ?? endDay

        return StatisticsHeatmapRange(
            start: startDay,
            end: endDay,
            gridStart: gridStart,
            gridEnd: gridEnd
        )
    }

    func activityDailyCounts(
        metric: StatisticsActivityMetric,
        range: StatisticsHeatmapRange,
        books: [StatisticsBookSnapshot],
        sessionBooks: [StatisticsSessionBookSnapshot]
    ) -> [Date: Int] {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = self.calendar.timeZone

        var counts: [Date: Int] = [:]

        func addDay(_ date: Date) {
            let day = calendar.startOfDay(for: date)
            guard day >= range.start && day <= range.end else { return }
            counts[day, default: 0] += 1
        }

        func addRange(from: Date, to: Date) {
            var day = calendar.startOfDay(for: from)
            let end = calendar.startOfDay(for: to)
            guard day <= end else { return }

            while day <= end {
                addDay(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        switch metric {
        case .readingMinutes:
            var secondsByDay: [Date: Int] = [:]

            func addSeconds(_ seconds: Int, on dayDate: Date) {
                let day = calendar.startOfDay(for: dayDate)
                guard day >= range.start && day <= range.end else { return }
                guard seconds > 0 else { return }
                secondsByDay[day, default: 0] += seconds
            }

            func addSession(start: Date, end: Date) {
                var start = start
                var end = end
                if end < start {
                    (start, end) = (end, start)
                }

                let clampedStart = max(start, range.start)
                let endAfterRange = calendar.date(byAdding: .day, value: 1, to: range.end) ?? range.end
                let clampedEnd = min(end, endAfterRange)
                guard clampedEnd > clampedStart else { return }

                var cursor = clampedStart
                while cursor < clampedEnd {
                    let dayStart = calendar.startOfDay(for: cursor)
                    guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
                    let segmentEnd = min(clampedEnd, nextDayStart)
                    let segmentSeconds = max(0, Int(segmentEnd.timeIntervalSince(cursor).rounded(.down)))
                    addSeconds(segmentSeconds, on: dayStart)
                    cursor = segmentEnd
                }
            }

            for book in sessionBooks {
                for session in book.readingSessions {
                    addSession(start: session.startedAt, end: session.endedAt)
                }
            }

            var minutes: [Date: Int] = [:]
            minutes.reserveCapacity(secondsByDay.count)
            for (day, seconds) in secondsByDay {
                let roundedMinutes = Int((Double(seconds) / 60.0).rounded())
                if roundedMinutes > 0 {
                    minutes[day] = roundedMinutes
                }
            }
            return minutes

        case .completions:
            for book in books {
                for completion in book.readingCompletions {
                    addDay(completion.finishedAt)
                }
            }

        case .readingDays:
            for book in books {
                for completion in book.readingCompletions {
                    if let from = completion.startedAt {
                        addRange(from: from, to: completion.finishedAt)
                    } else {
                        addDay(completion.finishedAt)
                    }
                }

                if book.status == .reading, let from = book.activeAttemptStartedAt ?? book.readFrom {
                    let clampedNow = min(range.end, calendar.startOfDay(for: now))
                    addRange(from: from, to: clampedNow)
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

        let ratio = Double(count) / Double(maxCount)
        if ratio <= 0.25 { return 1 }
        if ratio <= 0.50 { return 2 }
        if ratio <= 0.75 { return 3 }
        return 4
    }

    func heatmapWeeks(
        counts: [Date: Int],
        range: StatisticsHeatmapRange
    ) -> [StatisticsHeatmapWeek] {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = self.calendar.timeZone

        let days = calendar.dateComponents([.day], from: range.gridStart, to: range.gridEnd).day ?? 0
        let weekCount = max(1, (days / 7) + 1)
        let maxCount = counts.values.max() ?? 0

        var weeks: [StatisticsHeatmapWeek] = []
        weeks.reserveCapacity(weekCount)

        for weekIndex in 0..<weekCount {
            let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: range.gridStart) ?? range.gridStart
            var weekDays: [StatisticsHeatmapDay] = []
            weekDays.reserveCapacity(7)

            for dayOffset in 0..<7 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
                let day = calendar.startOfDay(for: date)
                let inRange = day >= range.start && day <= range.end
                let count = inRange ? (counts[day] ?? 0) : 0
                let level = inRange ? heatLevel(count: count, maxCount: maxCount) : 0

                weekDays.append(
                    StatisticsHeatmapDay(
                        id: day,
                        date: day,
                        count: count,
                        level: level,
                        isInRange: inRange
                    )
                )
            }

            weeks.append(StatisticsHeatmapWeek(id: weekIndex, days: weekDays))
        }

        return weeks
    }

    func heatmapStats(
        counts: [Date: Int],
        range: StatisticsHeatmapRange,
        metric: StatisticsActivityMetric,
        fallbackYear: Int? = nil
    ) -> StatisticsHeatmapStats {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = self.calendar.timeZone

        let fallbackYear = fallbackYear ?? calendar.component(.year, from: now)
        let maxCount = counts.values.max() ?? 0
        let activeDays = counts.values.filter { $0 > 0 }.count
        let unitSuffix = metric.unitSuffix

        var bestDay: Date? = nil
        var bestDayCount = 0
        for (date, count) in counts where count > 0 {
            if count > bestDayCount {
                bestDay = date
                bestDayCount = count
            } else if count == bestDayCount {
                if let currentBest = bestDay {
                    if date < currentBest {
                        bestDay = date
                    }
                } else {
                    bestDay = date
                }
            }
        }

        let bestDayLabel: String
        if let bestDay {
            bestDayLabel = "\(bestDay.formatted(date: .abbreviated, time: .omitted)) • \(formatInt(bestDayCount))\(unitSuffix)"
        } else {
            bestDayLabel = "–"
        }

        let weekdayLabels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        var weekdaySums = Array(repeating: 0, count: 7)
        for (date, count) in counts where count > 0 {
            let weekday = calendar.component(.weekday, from: date)
            let index = (weekday + 5) % 7
            weekdaySums[index] += count
        }

        let bestWeekdayIndex = weekdaySums.enumerated().max(by: { $0.element < $1.element })?.offset
        let bestWeekdayLabel: String
        if let bestWeekdayIndex, weekdaySums[bestWeekdayIndex] > 0 {
            bestWeekdayLabel = "\(weekdayLabels[bestWeekdayIndex]) • \(formatInt(weekdaySums[bestWeekdayIndex]))\(unitSuffix)"
        } else {
            bestWeekdayLabel = "–"
        }

        var weekSums: [WeekKey: Int] = [:]
        for (date, count) in counts where count > 0 {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            let year = components.yearForWeekOfYear ?? fallbackYear
            let week = components.weekOfYear ?? 0
            let key = WeekKey(year: year, week: week)
            weekSums[key, default: 0] += count
        }

        var bestWeekKey: WeekKey? = nil
        var bestWeekSum = 0
        for (key, sum) in weekSums {
            if sum > bestWeekSum {
                bestWeekKey = key
                bestWeekSum = sum
            } else if sum == bestWeekSum {
                if let currentBest = bestWeekKey {
                    if key < currentBest {
                        bestWeekKey = key
                    }
                } else {
                    bestWeekKey = key
                }
            }
        }

        let bestWeekLabel: String
        if let bestWeekKey, bestWeekSum > 0 {
            bestWeekLabel = "KW \(bestWeekKey.week) (\(bestWeekKey.year)) • \(formatInt(bestWeekSum))\(unitSuffix)"
        } else {
            bestWeekLabel = "–"
        }

        func count(on date: Date) -> Int {
            counts[calendar.startOfDay(for: date)] ?? 0
        }

        var currentStreak = 0
        var cursor = range.end
        while cursor >= range.start && count(on: cursor) > 0 {
            currentStreak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        var longestStreak = 0
        var runningStreak = 0
        var day = range.start
        while day <= range.end {
            if count(on: day) > 0 {
                runningStreak += 1
                longestStreak = max(longestStreak, runningStreak)
            } else {
                runningStreak = 0
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return StatisticsHeatmapStats(
            activeDays: activeDays,
            maxCount: maxCount,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            bestDayLabel: bestDayLabel,
            bestWeekdayLabel: bestWeekdayLabel,
            bestWeekLabel: bestWeekLabel
        )
    }

    private nonisolated struct WeekKey: Hashable, Comparable {
        let year: Int
        let week: Int

        static func < (lhs: WeekKey, rhs: WeekKey) -> Bool {
            if lhs.year != rhs.year {
                return lhs.year < rhs.year
            }
            return lhs.week < rhs.week
        }
    }

    func formatInt(_ value: Int) -> String {
        value.formatted(
            .number
                .grouping(.automatic)
                .locale(Locale(identifier: "de_DE"))
        )
    }
}
