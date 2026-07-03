import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryHomeSnapshotBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    @Test func continueReadingPrefersNewestActiveSession() {
        let olderSession = makeBook(
            id: fixedID(1),
            title: "Older Session",
            status: .reading,
            createdAt: date(2026, 1, 10),
            lastSessionAt: date(2026, 1, 12)
        )
        let newerSession = makeBook(
            id: fixedID(2),
            title: "Newer Session",
            status: .reading,
            createdAt: date(2026, 1, 1),
            lastSessionAt: date(2026, 1, 20)
        )
        let newestCreatedWithoutSession = makeBook(
            id: fixedID(3),
            title: "Newest Created",
            status: .reading,
            createdAt: date(2026, 2, 1)
        )

        let snapshot = LibraryView.LibraryHomeSnapshotBuilder.makeSnapshot(
            books: [olderSession, newestCreatedWithoutSession, newerSession]
        )

        #expect(snapshot.continueReadingBookID == newerSession.id)
    }

    @Test func continueReadingFallsBackToNewestReadingBookWithoutSessions() {
        let older = makeBook(
            id: fixedID(1),
            title: "Older",
            status: .reading,
            createdAt: date(2026, 1, 1)
        )
        let newer = makeBook(
            id: fixedID(2),
            title: "Newer",
            status: .reading,
            createdAt: date(2026, 1, 8)
        )
        let toRead = makeBook(
            id: fixedID(3),
            title: "Stack",
            status: .toRead,
            createdAt: date(2026, 2, 1)
        )

        let snapshot = LibraryView.LibraryHomeSnapshotBuilder.makeSnapshot(
            books: [older, toRead, newer]
        )

        #expect(snapshot.continueReadingBookID == newer.id)
    }

    @Test func continueReadingIsEmptyWhenNoReadingBookExists() {
        let books = [
            makeBook(id: fixedID(1), title: "Stack", status: .toRead, createdAt: date(2026, 1, 1)),
            makeBook(id: fixedID(2), title: "Done", status: .finished, createdAt: date(2026, 1, 2), readTo: date(2026, 1, 5))
        ]

        let snapshot = LibraryView.LibraryHomeSnapshotBuilder.makeSnapshot(books: books)

        #expect(snapshot.continueReadingBookID == nil)
    }

    @Test func quickStatsCountAllReadingStackAndFinishedBooks() {
        let books = [
            makeBook(id: fixedID(1), title: "Stack", status: .toRead, createdAt: date(2026, 1, 1)),
            makeBook(id: fixedID(2), title: "Current", status: .reading, createdAt: date(2026, 1, 2)),
            makeBook(id: fixedID(3), title: "Done", status: .finished, createdAt: date(2026, 1, 3))
        ]

        let snapshot = LibraryView.LibraryHomeSnapshotBuilder.makeSnapshot(books: books)
        let valuesByID = Dictionary(uniqueKeysWithValues: snapshot.quickStats.map { ($0.id, $0.value) })

        #expect(valuesByID["total"] == 3)
        #expect(valuesByID[ReadingStatus.reading.rawValue] == 1)
        #expect(valuesByID[ReadingStatus.toRead.rawValue] == 1)
        #expect(valuesByID[ReadingStatus.finished.rawValue] == 1)
    }

    @Test func lanesAreSortedAndLimited() {
        let firstReading = makeBook(
            id: fixedID(1),
            title: "Reading One",
            status: .reading,
            createdAt: date(2026, 1, 1),
            lastSessionAt: date(2026, 1, 5)
        )
        let secondReading = makeBook(
            id: fixedID(2),
            title: "Reading Two",
            status: .reading,
            createdAt: date(2026, 1, 2),
            lastSessionAt: date(2026, 1, 8)
        )
        let newest = makeBook(
            id: fixedID(3),
            title: "Newest",
            status: .toRead,
            createdAt: date(2026, 2, 1)
        )
        let finishedOlder = makeBook(
            id: fixedID(4),
            title: "Finished Older",
            status: .finished,
            createdAt: date(2026, 1, 3),
            readTo: date(2026, 1, 10),
            userRatingAverage1: 4.8
        )
        let finishedNewer = makeBook(
            id: fixedID(5),
            title: "Finished Newer",
            status: .finished,
            createdAt: date(2026, 1, 4),
            readTo: date(2026, 1, 20),
            userRatingAverage1: 4.2
        )

        let snapshot = LibraryView.LibraryHomeSnapshotBuilder.makeSnapshot(
            books: [firstReading, secondReading, newest, finishedOlder, finishedNewer],
            laneLimit: 2
        )
        let lanesByKind = Dictionary(uniqueKeysWithValues: snapshot.lanes.map { ($0.kind, $0.bookIDs) })

        #expect(lanesByKind[.currentlyReading] == [secondReading.id, firstReading.id])
        #expect(lanesByKind[.recentlyAdded] == [newest.id, finishedNewer.id])
        #expect(lanesByKind[.recentlyFinished] == [finishedNewer.id, finishedOlder.id])
        #expect(lanesByKind[.topRated] == [finishedOlder.id, finishedNewer.id])
    }

    @Test func topRatedLaneOnlyUsesRatedFinishedBooksWithStableTieBreaker() {
        let lowerID = fixedID(1)
        let higherID = fixedID(2)
        let firstRated = makeBook(
            id: higherID,
            title: "Rated B",
            status: .finished,
            createdAt: date(2026, 1, 1),
            readTo: date(2026, 1, 10),
            userRatingAverage1: 4.5
        )
        let secondRated = makeBook(
            id: lowerID,
            title: "Rated A",
            status: .finished,
            createdAt: date(2026, 1, 1),
            readTo: date(2026, 1, 10),
            userRatingAverage1: 4.5
        )
        let unratedFinished = makeBook(
            id: fixedID(3),
            title: "Unrated",
            status: .finished,
            createdAt: date(2026, 1, 2),
            readTo: date(2026, 1, 12)
        )
        let ratedReading = makeBook(
            id: fixedID(4),
            title: "Rated Reading",
            status: .reading,
            createdAt: date(2026, 1, 3),
            userRatingAverage1: 5.0
        )

        let snapshot = LibraryView.LibraryHomeSnapshotBuilder.makeSnapshot(
            books: [firstRated, unratedFinished, ratedReading, secondRated]
        )
        let topRatedIDs = snapshot.lanes.first { $0.kind == .topRated }?.bookIDs

        #expect(topRatedIDs == [lowerID, higherID])
    }

    private func makeBook(
        id: UUID,
        title: String,
        status: ReadingStatus,
        createdAt: Date,
        readFrom: Date? = nil,
        readTo: Date? = nil,
        lastSessionAt: Date? = nil,
        userRatingAverage1: Double? = nil
    ) -> LibraryView.LibrarySourceSnapshot.BookSnapshot {
        LibraryView.LibrarySourceSnapshot.BookSnapshot(
            id: id,
            title: title,
            createdAt: createdAt,
            statusRawValue: status.rawValue,
            readFrom: readFrom,
            readTo: readTo,
            lastSessionAt: lastSessionAt,
            hasUserRating: userRatingAverage1 != nil,
            userRatingAverage1: userRatingAverage1
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}
