import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryWidgetSnapshotBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        ) ?? .distantPast
    }

    @Test func emptyLibraryProducesEmptySnapshot() {
        let snapshot = LibraryWidgetSnapshotBuilder.make(
            books: [],
            goals: [],
            sessions: [],
            generatedAt: date(2026, 4, 15),
            calendar: calendar
        )

        #expect(snapshot.state == .emptyLibrary)
        #expect(snapshot.totalBooks == 0)
        #expect(snapshot.readBooks == 0)
        #expect(snapshot.readingBooks == 0)
        #expect(snapshot.wantToReadBooks == 0)
        #expect(snapshot.currentBook == nil)
        #expect(snapshot.yearlyGoal == nil)
        #expect(snapshot.recentShelfItems.isEmpty)
    }

    @Test func mixedLibraryCountsStatusesAndGoalProgress() {
        let finished = makeBook(
            id: fixedID(1),
            title: "Finished",
            status: .finished,
            createdAt: date(2026, 1, 1),
            readFrom: date(2026, 1, 2),
            readTo: date(2026, 1, 10),
            pageCount: 300,
            completions: [
                makeCompletion(bookID: fixedID(1), finishedAt: date(2026, 1, 10), pageCount: 300)
            ]
        )
        let reading = makeBook(
            id: fixedID(2),
            title: "Reading",
            status: .reading,
            createdAt: date(2026, 2, 1),
            pageCount: 400,
            pagesRead: 120,
            lastSessionAt: date(2026, 4, 15, 8)
        )
        let toRead = makeBook(
            id: fixedID(3),
            title: "To Read",
            status: .toRead,
            createdAt: date(2026, 3, 1)
        )
        let goal = LibraryWidgetGoalRecord(
            year: 2026,
            targetCount: 12,
            updatedAt: date(2026, 1, 1)
        )

        let snapshot = LibraryWidgetSnapshotBuilder.make(
            books: [toRead, reading, finished],
            goals: [goal],
            sessions: [],
            generatedAt: date(2026, 4, 15),
            calendar: calendar
        )

        #expect(snapshot.state == .ready)
        #expect(snapshot.totalBooks == 3)
        #expect(snapshot.readBooks == 1)
        #expect(snapshot.readingBooks == 1)
        #expect(snapshot.wantToReadBooks == 1)
        #expect(snapshot.currentBook?.id == fixedID(2))
        #expect(snapshot.currentBook?.pagesRead == 120)
        #expect(snapshot.currentBook?.remainingPages == 280)
        #expect(abs((snapshot.currentBook?.progressFraction ?? 0) - 0.3) < 0.0001)
        #expect(snapshot.yearlyGoal?.year == 2026)
        #expect(snapshot.yearlyGoal?.targetCount == 12)
        #expect(snapshot.yearlyGoal?.finishedCount == 1)
        #expect(snapshot.yearlyGoal?.remainingCount == 11)
    }

    @Test func activeBookIDWinsOverNewestReadingBook() {
        let olderActive = makeBook(
            id: fixedID(1),
            title: "Active Timer",
            status: .reading,
            createdAt: date(2026, 1, 1),
            lastSessionAt: date(2026, 3, 1)
        )
        let newerReading = makeBook(
            id: fixedID(2),
            title: "Newest Session",
            status: .reading,
            createdAt: date(2026, 1, 2),
            lastSessionAt: date(2026, 4, 15)
        )

        let snapshot = LibraryWidgetSnapshotBuilder.make(
            books: [newerReading, olderActive],
            goals: [],
            sessions: [],
            activeBookID: fixedID(1),
            generatedAt: date(2026, 4, 15),
            calendar: calendar
        )

        #expect(snapshot.currentBook?.id == fixedID(1))
        #expect(snapshot.currentBook?.title == "Active Timer")
    }

    @Test func missingPageCountKeepsPagesButOmitsProgressAndRemainingPages() {
        let reading = makeBook(
            id: fixedID(1),
            title: "No Page Count",
            status: .reading,
            createdAt: date(2026, 1, 1),
            pageCount: nil,
            pagesRead: 42,
            lastSessionAt: date(2026, 4, 15)
        )

        let snapshot = LibraryWidgetSnapshotBuilder.make(
            books: [reading],
            goals: [],
            sessions: [],
            generatedAt: date(2026, 4, 15),
            calendar: calendar
        )

        #expect(snapshot.currentBook?.pageCount == nil)
        #expect(snapshot.currentBook?.pagesRead == 42)
        #expect(snapshot.currentBook?.remainingPages == nil)
        #expect(snapshot.currentBook?.progressFraction == nil)
    }

    @Test func missingYearlyGoalLeavesGoalSnapshotEmpty() {
        let finished = makeBook(
            id: fixedID(1),
            title: "Finished",
            status: .finished,
            createdAt: date(2026, 1, 1),
            readTo: date(2026, 1, 10),
            completions: [
                makeCompletion(bookID: fixedID(1), finishedAt: date(2026, 1, 10))
            ]
        )

        let snapshot = LibraryWidgetSnapshotBuilder.make(
            books: [finished],
            goals: [],
            sessions: [],
            generatedAt: date(2026, 4, 15),
            calendar: calendar
        )

        #expect(snapshot.yearlyGoal == nil)
    }

    @Test func recentActivityUsesLastSevenDaysAndCurrentStreak() {
        let book = makeBook(
            id: fixedID(1),
            title: "Reading",
            status: .reading,
            createdAt: date(2026, 1, 1)
        )
        let sessions = [
            makeSession(id: fixedID(11), startedAt: date(2026, 4, 15, 8), durationSeconds: 1_200),
            makeSession(id: fixedID(12), startedAt: date(2026, 4, 14, 8), durationSeconds: 1_800),
            makeSession(id: fixedID(13), startedAt: date(2026, 4, 8, 8), durationSeconds: 3_600)
        ]

        let snapshot = LibraryWidgetSnapshotBuilder.make(
            books: [book],
            goals: [],
            sessions: sessions,
            generatedAt: date(2026, 4, 15, 9),
            calendar: calendar
        )

        #expect(snapshot.last7DaysReadingMinutes == 50)
        #expect(snapshot.last7DaysReadingDays == 2)
        #expect(snapshot.currentReadingStreakDays == 2)
    }

    @Test func recentShelfItemsPreferRecentlyFinishedBooksWithStableOrdering() {
        let alpha = makeBook(
            id: fixedID(1),
            title: "Alpha",
            status: .finished,
            createdAt: date(2026, 1, 1),
            completions: [makeCompletion(bookID: fixedID(1), finishedAt: date(2026, 2, 1))]
        )
        let beta = makeBook(
            id: fixedID(2),
            title: "Beta",
            status: .finished,
            createdAt: date(2026, 1, 2),
            completions: [makeCompletion(bookID: fixedID(2), finishedAt: date(2026, 3, 1))]
        )
        let gamma = makeBook(
            id: fixedID(3),
            title: "Gamma",
            status: .finished,
            createdAt: date(2026, 1, 3),
            completions: [makeCompletion(bookID: fixedID(3), finishedAt: date(2026, 3, 1))]
        )

        let snapshot = LibraryWidgetSnapshotBuilder.make(
            books: [alpha, beta, gamma],
            goals: [],
            sessions: [],
            generatedAt: date(2026, 4, 15),
            calendar: calendar
        )

        #expect(snapshot.recentShelfItems.map(\.title) == ["Gamma", "Beta", "Alpha"])
        #expect(snapshot.recentShelfItems.allSatisfy { $0.kind == .recentlyFinished })
    }

    @Test func recentShelfItemsFallBackToRecentlyAddedBooksWhenNothingIsFinished() {
        let alpha = makeBook(
            id: fixedID(1),
            title: "Alpha",
            status: .toRead,
            createdAt: date(2026, 1, 1)
        )
        let beta = makeBook(
            id: fixedID(2),
            title: "Beta",
            status: .toRead,
            createdAt: date(2026, 2, 1)
        )

        let snapshot = LibraryWidgetSnapshotBuilder.make(
            books: [alpha, beta],
            goals: [],
            sessions: [],
            generatedAt: date(2026, 4, 15),
            calendar: calendar
        )

        #expect(snapshot.recentShelfItems.map(\.title) == ["Beta", "Alpha"])
        #expect(snapshot.recentShelfItems.allSatisfy { $0.kind == .recentlyAdded })
    }

    private func makeBook(
        id: UUID,
        title: String,
        author: String = "",
        status: ReadingStatus,
        createdAt: Date,
        readFrom: Date? = nil,
        readTo: Date? = nil,
        pageCount: Int? = nil,
        pagesRead: Int = 0,
        lastSessionAt: Date? = nil,
        completions: [LibraryWidgetCompletionRecord] = []
    ) -> LibraryWidgetBookRecord {
        LibraryWidgetBookRecord(
            id: id,
            title: title,
            author: author,
            statusRawValue: status.rawValue,
            createdAt: createdAt,
            readFrom: readFrom,
            readTo: readTo,
            pageCount: pageCount,
            pagesRead: pagesRead,
            lastSessionAt: lastSessionAt,
            completions: completions
        )
    }

    private func makeCompletion(
        bookID: UUID,
        finishedAt: Date,
        pageCount: Int? = nil,
        sequenceNumber: Int = 1
    ) -> LibraryWidgetCompletionRecord {
        LibraryWidgetCompletionRecord(
            id: "completion-\(bookID.uuidString)-\(sequenceNumber)",
            bookID: bookID,
            sequenceNumber: sequenceNumber,
            finishedAt: finishedAt,
            pageCount: pageCount,
            isReread: sequenceNumber > 1
        )
    }

    private func makeSession(
        id: UUID,
        startedAt: Date,
        durationSeconds: Int
    ) -> LibraryWidgetSessionRecord {
        LibraryWidgetSessionRecord(
            id: id,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            createdAt: startedAt
        )
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}
