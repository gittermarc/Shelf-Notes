import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeTemplateProgressTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    @Test func computesShortSessionsAndSessionNotes() {
        let start = date(2026, 6, 1)
        let end = date(2026, 6, 8)
        let snapshot = ChallengeEngine.Snapshot(
            sessions: [
                ChallengeEngine.SessionSnapshot(
                    bookID: UUID(uuidString: "00000000-0000-0000-0000-000000001201"),
                    startedAt: date(2026, 6, 2, 10),
                    endedAt: date(2026, 6, 2, 10, 20),
                    durationSeconds: 20 * 60,
                    pagesRead: 12,
                    hasNote: true
                ),
                ChallengeEngine.SessionSnapshot(
                    bookID: UUID(uuidString: "00000000-0000-0000-0000-000000001202"),
                    startedAt: date(2026, 6, 3, 10),
                    endedAt: date(2026, 6, 3, 11),
                    durationSeconds: 60 * 60,
                    pagesRead: 30,
                    hasNote: false
                )
            ],
            finishedBookReadTo: []
        )

        let short = ChallengeEngine.computeProgress(metric: .shortSessions, window: start..<end, snapshot: snapshot)
        let notes = ChallengeEngine.computeProgress(metric: .sessionNotes, window: start..<end, snapshot: snapshot)

        #expect(short.value == 1)
        #expect(notes.value == 1)
    }

    @Test func computesDistinctBooksProgressed() {
        let bookID = UUID(uuidString: "00000000-0000-0000-0000-000000001301") ?? UUID()
        let otherBookID = UUID(uuidString: "00000000-0000-0000-0000-000000001302") ?? UUID()
        let start = date(2026, 6, 1)
        let end = date(2026, 6, 8)
        let snapshot = ChallengeEngine.Snapshot(
            sessions: [
                ChallengeEngine.SessionSnapshot(bookID: bookID, startedAt: date(2026, 6, 2), endedAt: date(2026, 6, 2, 12, 30), durationSeconds: 30 * 60, pagesRead: 15),
                ChallengeEngine.SessionSnapshot(bookID: bookID, startedAt: date(2026, 6, 3), endedAt: date(2026, 6, 3, 12, 30), durationSeconds: 30 * 60, pagesRead: 20),
                ChallengeEngine.SessionSnapshot(bookID: otherBookID, startedAt: date(2026, 6, 4), endedAt: date(2026, 6, 4, 12, 30), durationSeconds: 30 * 60, pagesRead: 10)
            ],
            finishedBookReadTo: []
        )

        let progressed = ChallengeEngine.computeProgress(metric: .booksProgressed, window: start..<end, snapshot: snapshot)

        #expect(progressed.value == 2)
    }

    @Test func computesRatedAndNotedFinishedBooks() {
        let start = date(2026, 6, 1)
        let end = date(2026, 7, 1)
        let snapshot = ChallengeEngine.Snapshot(
            sessions: [],
            finishedBooks: [
                ChallengeEngine.FinishedBookSnapshot(readTo: date(2026, 6, 5), hasUserNote: true, hasUserRating: true),
                ChallengeEngine.FinishedBookSnapshot(readTo: date(2026, 6, 12), hasUserNote: false, hasUserRating: true),
                ChallengeEngine.FinishedBookSnapshot(readTo: date(2026, 5, 28), hasUserNote: true, hasUserRating: true)
            ]
        )

        let rated = ChallengeEngine.computeProgress(metric: .finishedBooksRated, window: start..<end, snapshot: snapshot)
        let noted = ChallengeEngine.computeProgress(metric: .finishedBooksNoted, window: start..<end, snapshot: snapshot)

        #expect(rated.value == 2)
        #expect(noted.value == 1)
    }

    @Test func booksFinishedCountsCompletedAttemptsForRereads() {
        let bookID = UUID(uuidString: "00000000-0000-0000-0000-000000004001") ?? UUID()
        let start = date(2026, 6, 1)
        let end = date(2026, 7, 1)
        let snapshot = ChallengeEngine.Snapshot(
            sessions: [],
            finishedBooks: [
                ChallengeEngine.FinishedBookSnapshot(
                    bookID: bookID,
                    attemptID: UUID(uuidString: "00000000-0000-0000-0000-000000004101"),
                    sequenceNumber: 1,
                    readTo: date(2026, 6, 5),
                    isReread: false
                ),
                ChallengeEngine.FinishedBookSnapshot(
                    bookID: bookID,
                    attemptID: UUID(uuidString: "00000000-0000-0000-0000-000000004102"),
                    sequenceNumber: 2,
                    readTo: date(2026, 6, 20),
                    isReread: true
                )
            ]
        )

        let progress = ChallengeEngine.computeProgress(metric: .booksFinished, window: start..<end, snapshot: snapshot)

        #expect(progress.value == 2)
        #expect(progress.unitSuffix == "Abschlüsse")
    }

}
