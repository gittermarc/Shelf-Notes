import Foundation

nonisolated enum ReadingAnalyticsInputMapper {
    static func bookRecords(from books: [Book]) -> [ReadingAnalyticsBookRecord] {
        books.map(ReadingAnalyticsBookRecord.init(book:))
    }

    static func sessionRecords(from sessions: [ReadingSession]) -> [ReadingAnalyticsSessionRecord] {
        sessions.map(ReadingAnalyticsSessionRecord.init(session:))
    }
}
