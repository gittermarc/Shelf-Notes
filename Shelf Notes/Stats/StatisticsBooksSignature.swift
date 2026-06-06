import Foundation

extension StatisticsSourceStore {
    static func booksSignature(_ books: [Book]) -> Int {
        var hasher = StableStatisticsHasher()
        hasher.combine("statistics-books-v4")
        hasher.combine(books.count)

        for book in books.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(book.id.uuidString)
            hasher.combine(book.title)
            hasher.combine(book.author)
            hasher.combine(book.statusRawValue)
            hasher.combineDay(book.readFrom)
            hasher.combineDay(book.readTo)
            hasher.combine(book.publisher)
            hasher.combine(book.publishedDate)
            hasher.combine(book.pageCount)
            hasher.combine(book.language)
            hasher.combine(book.subtitle)
            hasher.combine(book.averageRating)
            hasher.combine(book.ratingsCount)
            hasher.combine(book.mainCategory)
            hasher.combine(book.userRatingPlot)
            hasher.combine(book.userRatingCharacters)
            hasher.combine(book.userRatingWritingStyle)
            hasher.combine(book.userRatingAtmosphere)
            hasher.combine(book.userRatingGenreFit)
            hasher.combine(book.userRatingPresentation)

            for category in book.categories.sorted() {
                hasher.combine(category)
            }
            hasher.combine("categories-end")

            for tag in book.tags.sorted() {
                hasher.combine(tag)
            }
            hasher.combine("tags-end")

            let attempts = book.orderedReadingAttempts
            hasher.combine(attempts.count)
            for attempt in attempts {
                hasher.combine(attempt.id.uuidString)
                hasher.combine(attempt.sequenceNumber)
                hasher.combine(attempt.statusRawValue)
                hasher.combineDay(attempt.startedAt)
                hasher.combineDay(attempt.finishedAt)
                hasher.combine(attempt.pageCountSnapshot)
                hasher.combineDate(attempt.updatedAt)
            }
            hasher.combine("attempts-end")

            hasher.combine("book-end")
        }

        return hasher.finalizeInt()
    }

    static func sessionsSignature(_ books: [Book]) -> Int {
        var hasher = StableStatisticsHasher()
        hasher.combine("statistics-sessions-v1")
        hasher.combine(books.count)

        for book in books.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(book.id.uuidString)
            hasher.combine(book.statusRawValue)

            let sessions = book.readingSessionsSafe.sorted { left, right in
                left.id.uuidString < right.id.uuidString
            }
            hasher.combine(sessions.count)

            for session in sessions {
                hasher.combine(session.id.uuidString)
                hasher.combineDate(session.startedAt)
                hasher.combineDate(session.endedAt)
                hasher.combine(session.durationSeconds)
            }

            hasher.combine("session-book-end")
        }

        return hasher.finalizeInt()
    }
}

private nonisolated struct StableStatisticsHasher {
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

    mutating func combine(_ value: Double?) {
        guard let value else {
            combine("<nil-double>")
            return
        }
        combine(String(value.bitPattern))
    }

    mutating func combineDate(_ date: Date?) {
        guard let date else {
            combine("<nil-date>")
            return
        }
        let milliseconds = Int64((date.timeIntervalSince1970 * 1_000).rounded())
        combine(String(milliseconds))
    }

    mutating func combineDay(_ date: Date?) {
        guard let date else {
            combine("<nil-day>")
            return
        }
        let day = Int(date.timeIntervalSince1970 / 86_400)
        combine(String(day))
    }

    func finalizeInt() -> Int {
        Int(truncatingIfNeeded: value)
    }

    private mutating func combineSeparator() {
        value ^= 0xFF
        value &*= prime
    }
}
