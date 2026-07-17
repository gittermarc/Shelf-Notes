import Foundation

nonisolated enum ReadingAnalyticsInputMapper {
    @MainActor static func bookRecords(from books: [Book]) -> [ReadingAnalyticsBookRecord] {
        books.map(ReadingAnalyticsBookRecord.init(book:))
    }

    @MainActor static func sessionRecords(from sessions: [ReadingSession]) -> [ReadingAnalyticsSessionRecord] {
        sessions.map(ReadingAnalyticsSessionRecord.init(session:))
    }
}
