import Foundation

nonisolated enum ReadingAnalyticsRecentActivityBuilder {
    struct Accumulator {
        private let activityCalendar: Calendar
        private let windowStart: Date

        private var secondsTotal: Int = 0
        private var daysWithActivityWindow = Set<Date>()
        private var streak: Int = 0
        private var expectedStreakDay: Date
        private var lastCountedStreakDay: Date?
        private var streakDone: Bool = false

        private(set) var shouldStop: Bool = false

        init(now: Date, calendar: Calendar) {
            var activityCalendar = Calendar(identifier: .iso8601)
            activityCalendar.timeZone = calendar.timeZone

            let today = activityCalendar.startOfDay(for: now)
            let windowStart = activityCalendar.date(byAdding: .day, value: -6, to: today) ?? today

            self.activityCalendar = activityCalendar
            self.windowStart = windowStart
            self.expectedStreakDay = today
        }

        mutating func consume(_ session: ReadingAnalyticsSessionRecord) {
            guard shouldStop == false else { return }

            let day = activityCalendar.startOfDay(for: session.startedAt)
            let duration = session.normalizedDurationSeconds

            if duration > 0 {
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
            }

            if day < windowStart && streakDone {
                shouldStop = true
            }
        }

        func makeRecentActivity() -> ReadingAnalyticsRecentActivity {
            ReadingAnalyticsRecentActivity(
                minutesLast7: Int((Double(secondsTotal) / 60.0).rounded()),
                activeDaysLast7: daysWithActivityWindow.count,
                currentStreak: streak
            )
        }
    }

    static func make(
        sessions: [ReadingAnalyticsSessionRecord],
        sessionsAreSortedDescending: Bool = false,
        now: Date,
        calendar: Calendar
    ) -> ReadingAnalyticsRecentActivity {
        let orderedSessions = sessionsAreSortedDescending
            ? sessions
            : sessions.sorted(by: compareSessionsDescending)

        var accumulator = Accumulator(now: now, calendar: calendar)

        for session in orderedSessions {
            accumulator.consume(session)

            if accumulator.shouldStop {
                break
            }
        }

        return accumulator.makeRecentActivity()
    }

    static func compareSessionsDescending(
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
