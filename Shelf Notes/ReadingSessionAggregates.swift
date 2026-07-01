import Foundation

nonisolated enum ReadingSessionAggregateScope: String, CaseIterable, Hashable, Sendable {
    case all
    case finished
    case reading
    case toRead

    init(status: ReadingStatus, hasCompletedReading: Bool) {
        if status == .finished || hasCompletedReading {
            self = .finished
        } else if status == .reading {
            self = .reading
        } else {
            self = .toRead
        }
    }
}

nonisolated struct ReadingSessionAggregateRecord: Hashable, Sendable {
    let id: UUID
    let bookID: UUID?
    let statusRawValue: String
    let hasCompletedReading: Bool
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let pagesRead: Int?
    let createdAt: Date

    init(
        id: UUID,
        bookID: UUID? = nil,
        statusRawValue: String = ReadingStatus.toRead.rawValue,
        hasCompletedReading: Bool = false,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        pagesRead: Int? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.bookID = bookID
        self.statusRawValue = statusRawValue
        self.hasCompletedReading = hasCompletedReading
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = max(0, durationSeconds)
        self.pagesRead = pagesRead.flatMap { $0 > 0 ? $0 : nil }
        self.createdAt = createdAt
    }

    var status: ReadingStatus {
        ReadingStatus.fromPersisted(statusRawValue) ?? .toRead
    }

    var aggregateScopes: [ReadingSessionAggregateScope] {
        [.all, ReadingSessionAggregateScope(status: status, hasCompletedReading: hasCompletedReading)]
    }

    var sessionRecord: ReadingAnalyticsSessionRecord {
        ReadingAnalyticsSessionRecord(
            id: id,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            createdAt: createdAt
        )
    }

    @MainActor init(session: ReadingSession) {
        let book = session.book
        self.init(
            id: session.id,
            bookID: book?.id,
            statusRawValue: book?.statusRawValue ?? ReadingStatus.toRead.rawValue,
            hasCompletedReading: (book?.completedReadingAttemptCount ?? 0) > 0,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            durationSeconds: session.durationSeconds,
            pagesRead: session.pagesReadNormalized,
            createdAt: session.createdAt
        )
    }
}

nonisolated struct ReadingSessionBookAggregate: Equatable, Sendable {
    let bookID: UUID
    let sessionCount: Int
    let totalSeconds: Int
    let totalPages: Int

    var totalMinutes: Int {
        Int((Double(totalSeconds) / 60.0).rounded())
    }
}

nonisolated struct ReadingSessionYearAggregate: Equatable, Sendable {
    let year: Int
    let sessionCount: Int
    let totalSeconds: Int
    let totalPages: Int
    let activeDays: Int

    var totalMinutes: Int {
        Int((Double(totalSeconds) / 60.0).rounded())
    }
}

nonisolated struct ReadingSessionAggregateSnapshot: Equatable, Sendable {
    let signature: Int
    let totalSessionCount: Int
    let recentActivity: ReadingAnalyticsRecentActivity
    let secondsByDayByScope: [ReadingSessionAggregateScope: [Date: Int]]
    let pagesByDayByScope: [ReadingSessionAggregateScope: [Date: Int]]
    let booksByID: [UUID: ReadingSessionBookAggregate]
    let yearsByYear: [Int: ReadingSessionYearAggregate]

    static let empty = ReadingSessionAggregateSnapshot(
        signature: 0,
        totalSessionCount: 0,
        recentActivity: .empty,
        secondsByDayByScope: Dictionary(
            uniqueKeysWithValues: ReadingSessionAggregateScope.allCases.map { scope in
                (scope, [Date: Int]())
            }
        ),
        pagesByDayByScope: Dictionary(
            uniqueKeysWithValues: ReadingSessionAggregateScope.allCases.map { scope in
                (scope, [Date: Int]())
            }
        ),
        booksByID: [:],
        yearsByYear: [:]
    )

    func roundedMinutesByDay(
        for scope: ReadingSessionAggregateScope,
        range: ClosedRange<Date>? = nil
    ) -> [Date: Int] {
        let secondsByDay = secondsByDayByScope[scope] ?? [:]
        var result: [Date: Int] = [:]
        result.reserveCapacity(secondsByDay.count)

        for (day, seconds) in secondsByDay {
            if let range, range.contains(day) == false {
                continue
            }
            let minutes = Int((Double(seconds) / 60.0).rounded())
            if minutes > 0 {
                result[day] = minutes
            }
        }

        return result
    }

    func pagesByDay(
        for scope: ReadingSessionAggregateScope,
        range: ClosedRange<Date>? = nil
    ) -> [Date: Int] {
        let pagesByDay = pagesByDayByScope[scope] ?? [:]
        guard let range else { return pagesByDay }
        return pagesByDay.filter { day, _ in range.contains(day) }
    }
}

nonisolated enum ReadingSessionAggregateBuilder {
    static func make(
        records: [ReadingSessionAggregateRecord],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ReadingSessionAggregateSnapshot {
        guard !records.isEmpty else {
            return .empty
        }

        var activityCalendar = Calendar(identifier: .iso8601)
        activityCalendar.timeZone = calendar.timeZone

        var secondsByDayByScope = Dictionary(
            uniqueKeysWithValues: ReadingSessionAggregateScope.allCases.map { ($0, [Date: Int]()) }
        )
        var pagesByDayByScope = Dictionary(
            uniqueKeysWithValues: ReadingSessionAggregateScope.allCases.map { ($0, [Date: Int]()) }
        )
        var bookAccumulators: [UUID: BookAccumulator] = [:]
        var yearAccumulators: [Int: YearAccumulator] = [:]
        var hasher = StableReadingSessionAggregateHasher()
        hasher.combine("reading-session-aggregates-v1")
        hasher.combine(records.count)

        let ordered = records.sorted { left, right in
            if left.startedAt != right.startedAt {
                return left.startedAt > right.startedAt
            }
            if left.createdAt != right.createdAt {
                return left.createdAt > right.createdAt
            }
            return left.id.uuidString > right.id.uuidString
        }

        var recentAccumulator = ReadingAnalyticsRecentActivityBuilder.Accumulator(
            now: now,
            calendar: calendar
        )

        for record in ordered {
            combine(record: record, into: &hasher)
            recentAccumulator.consume(record.sessionRecord)

            let daySegments = splitSessionByDay(
                start: record.startedAt,
                end: record.endedAt,
                calendar: activityCalendar
            )
            let fallbackDay = activityCalendar.startOfDay(for: record.startedAt)
            let sessionSeconds = max(0, record.durationSeconds)
            let segments = daySegments.isEmpty ? [(fallbackDay, sessionSeconds)] : daySegments

            for scope in record.aggregateScopes {
                for (day, seconds) in segments where seconds > 0 {
                    secondsByDayByScope[scope, default: [:]][day, default: 0] += seconds
                }
                if let pagesRead = record.pagesRead {
                    pagesByDayByScope[scope, default: [:]][fallbackDay, default: 0] += pagesRead
                }
            }

            if let bookID = record.bookID {
                var accumulator = bookAccumulators[bookID] ?? BookAccumulator(bookID: bookID)
                accumulator.sessionCount += 1
                accumulator.totalSeconds += sessionSeconds
                accumulator.totalPages += record.pagesRead ?? 0
                bookAccumulators[bookID] = accumulator
            }

            let year = activityCalendar.component(.year, from: fallbackDay)
            var yearAccumulator = yearAccumulators[year] ?? YearAccumulator(year: year)
            yearAccumulator.sessionCount += 1
            yearAccumulator.totalSeconds += sessionSeconds
            yearAccumulator.totalPages += record.pagesRead ?? 0
            yearAccumulator.activeDays.insert(fallbackDay)
            yearAccumulators[year] = yearAccumulator
        }

        return ReadingSessionAggregateSnapshot(
            signature: hasher.finalizeInt(),
            totalSessionCount: records.count,
            recentActivity: recentAccumulator.makeRecentActivity(),
            secondsByDayByScope: secondsByDayByScope,
            pagesByDayByScope: pagesByDayByScope,
            booksByID: Dictionary(uniqueKeysWithValues: bookAccumulators.map { key, value in
                (key, value.makeAggregate())
            }),
            yearsByYear: Dictionary(uniqueKeysWithValues: yearAccumulators.map { key, value in
                (key, value.makeAggregate())
            })
        )
    }
}

private nonisolated extension ReadingSessionAggregateBuilder {
    static func splitSessionByDay(
        start: Date,
        end: Date,
        calendar: Calendar
    ) -> [(Date, Int)] {
        var start = start
        var end = end
        if end < start {
            (start, end) = (end, start)
        }
        guard end > start else { return [] }

        var result: [(Date, Int)] = []
        var cursor = start
        while cursor < end {
            let dayStart = calendar.startOfDay(for: cursor)
            guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                break
            }
            let segmentEnd = min(end, nextDayStart)
            let seconds = max(0, Int(segmentEnd.timeIntervalSince(cursor).rounded(.down)))
            if seconds > 0 {
                result.append((dayStart, seconds))
            }
            cursor = segmentEnd
        }
        return result
    }

    static func combine(
        record: ReadingSessionAggregateRecord,
        into hasher: inout StableReadingSessionAggregateHasher
    ) {
        hasher.combine(record.id.uuidString)
        hasher.combine(record.bookID?.uuidString)
        hasher.combine(record.statusRawValue)
        hasher.combine(record.hasCompletedReading ? 1 : 0)
        hasher.combineDate(record.startedAt)
        hasher.combineDate(record.endedAt)
        hasher.combine(record.durationSeconds)
        hasher.combine(record.pagesRead)
        hasher.combineDate(record.createdAt)
    }
}

private nonisolated struct BookAccumulator {
    let bookID: UUID
    var sessionCount: Int = 0
    var totalSeconds: Int = 0
    var totalPages: Int = 0

    func makeAggregate() -> ReadingSessionBookAggregate {
        ReadingSessionBookAggregate(
            bookID: bookID,
            sessionCount: sessionCount,
            totalSeconds: totalSeconds,
            totalPages: totalPages
        )
    }
}

private nonisolated struct YearAccumulator {
    let year: Int
    var sessionCount: Int = 0
    var totalSeconds: Int = 0
    var totalPages: Int = 0
    var activeDays: Set<Date> = []

    func makeAggregate() -> ReadingSessionYearAggregate {
        ReadingSessionYearAggregate(
            year: year,
            sessionCount: sessionCount,
            totalSeconds: totalSeconds,
            totalPages: totalPages,
            activeDays: activeDays.count
        )
    }
}

private nonisolated struct StableReadingSessionAggregateHasher {
    private var value: UInt64 = 14_695_981_039_346_656_037
    private let prime: UInt64 = 1_099_511_628_211

    mutating func combine(_ value: String?) {
        combine(value ?? "<nil>")
    }

    mutating func combine(_ value: String) {
        for byte in value.utf8 {
            self.value ^= UInt64(byte)
            self.value &*= prime
        }
        combineSeparator()
    }

    mutating func combine(_ value: Int?) {
        guard let value else {
            combine("<nil-int>")
            return
        }
        combine(String(value))
    }

    mutating func combineDate(_ date: Date?) {
        guard let date else {
            combine("<nil-date>")
            return
        }
        let milliseconds = Int64((date.timeIntervalSince1970 * 1_000).rounded())
        combine(String(milliseconds))
    }

    func finalizeInt() -> Int {
        Int(truncatingIfNeeded: value)
    }

    private mutating func combineSeparator() {
        value ^= 0xFF
        value &*= prime
    }
}
