import Foundation

nonisolated enum ReadingAnalyticsIndexBuilder {
    static func make(
        books: [ReadingAnalyticsBookRecord],
        sessions: [ReadingAnalyticsSessionRecord],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ReadingAnalyticsIndex {
        let yearSummaries = makeYearSummaries(from: books, calendar: calendar)
        let finishedBookYears = yearSummaries.keys.sorted(by: >)
        let recentActivity = makeRecentActivity(from: sessions, now: now, calendar: calendar)

        return ReadingAnalyticsIndex(
            finishedBookYears: finishedBookYears,
            yearSummaries: yearSummaries,
            recentActivity: recentActivity
        )
    }

    private static func makeYearSummaries(
        from books: [ReadingAnalyticsBookRecord],
        calendar: Calendar
    ) -> [Int: ReadingAnalyticsYearSummary] {
        var accumulators: [Int: YearAccumulator] = [:]

        for book in books {
            guard book.isFinished else { continue }
            guard let keyDate = book.readKeyDate else { continue }

            let year = calendar.component(.year, from: keyDate)
            let month = calendar.component(.month, from: keyDate)
            let pages = book.normalizedPageCount

            var accumulator = accumulators[year] ?? YearAccumulator()
            accumulator.finishedBookCount += 1
            accumulator.pagesRead += pages

            if pages > 0 {
                accumulator.countedBooksWithPagesCount += 1
            }

            accumulator.pagesByMonth[month, default: 0] += pages
            accumulators[year] = accumulator
        }

        return Dictionary(uniqueKeysWithValues: accumulators.map { year, accumulator in
            let averagePagesPerBook: Int?
            if accumulator.countedBooksWithPagesCount == 0 {
                averagePagesPerBook = nil
            } else {
                averagePagesPerBook = Int(
                    (
                        Double(accumulator.pagesRead) /
                        Double(accumulator.countedBooksWithPagesCount)
                    ).rounded()
                )
            }

            return (
                year,
                ReadingAnalyticsYearSummary(
                    year: year,
                    finishedBookCount: accumulator.finishedBookCount,
                    pagesRead: accumulator.pagesRead,
                    countedBooksWithPagesCount: accumulator.countedBooksWithPagesCount,
                    averagePagesPerBook: averagePagesPerBook,
                    pagesByMonth: accumulator.pagesByMonth
                )
            )
        })
    }

    private static func makeRecentActivity(
        from sessions: [ReadingAnalyticsSessionRecord],
        now: Date,
        calendar: Calendar
    ) -> ReadingAnalyticsRecentActivity {
        var activityCalendar = Calendar(identifier: .iso8601)
        activityCalendar.timeZone = calendar.timeZone

        let today = activityCalendar.startOfDay(for: now)
        let windowStart = activityCalendar.date(byAdding: .day, value: -6, to: today) ?? today
        let orderedSessions = sessions.sorted(by: compareSessionsDescending)

        var secondsTotal = 0
        var daysWithActivityWindow = Set<Date>()

        var streak = 0
        var expectedStreakDay = today
        var lastCountedStreakDay: Date? = nil
        var streakDone = false

        for session in orderedSessions {
            let duration = session.normalizedDurationSeconds
            if duration <= 0 { continue }

            let day = activityCalendar.startOfDay(for: session.startedAt)

            if day >= windowStart {
                secondsTotal += duration
                daysWithActivityWindow.insert(day)
            }

            if streakDone == false {
                if day == expectedStreakDay {
                    if lastCountedStreakDay != day {
                        streak += 1
                        lastCountedStreakDay = day
                        expectedStreakDay = activityCalendar.date(byAdding: .day, value: -1, to: expectedStreakDay) ?? expectedStreakDay
                    }
                } else if day < expectedStreakDay {
                    streakDone = true
                }
            }

            if day < windowStart && streakDone {
                break
            }
        }

        return ReadingAnalyticsRecentActivity(
            minutesLast7: Int((Double(secondsTotal) / 60.0).rounded()),
            activeDaysLast7: daysWithActivityWindow.count,
            currentStreak: streak
        )
    }

    private static func compareSessionsDescending(
        _ lhs: ReadingAnalyticsSessionRecord,
        _ rhs: ReadingAnalyticsSessionRecord
    ) -> Bool {
        if lhs.startedAt != rhs.startedAt {
            return lhs.startedAt > rhs.startedAt
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.id.uuidString > rhs.id.uuidString
    }
}

private nonisolated struct YearAccumulator {
    var finishedBookCount: Int = 0
    var pagesRead: Int = 0
    var countedBooksWithPagesCount: Int = 0
    var pagesByMonth: [Int: Int] = [:]
}
