import Foundation
import Testing
@testable import Shelf_Notes

struct LibrarySourceSnapshotTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    @Test @MainActor func bookSnapshotPreparesSmartShelfValuesFromBook() {
        let book = Book(title: "Dune", author: "Frank Herbert", status: .reading, tags: ["Sci-Fi"])
        book.id = fixedID(1)
        book.createdAt = date(2026, 1, 1)
        book.pageCount = 300
        book.userCoverData = Data([1, 2, 3])
        book.userRatingPlot = 5
        book.collectionsSafe = [BookCollection(name: "Favorites")]

        let completedAttempt = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .finished,
            startedAt: date(2025, 12, 1),
            finishedAt: date(2025, 12, 10),
            pageCountSnapshot: 300,
            createdAt: date(2025, 12, 1),
            updatedAt: date(2025, 12, 10)
        )
        let activeAttempt = ReadingAttempt(
            book: book,
            sequenceNumber: 2,
            status: .active,
            startedAt: date(2026, 1, 5),
            createdAt: date(2026, 1, 5),
            updatedAt: date(2026, 1, 5)
        )
        let oldSession = ReadingSession(
            book: book,
            startedAt: date(2025, 12, 2),
            endedAt: date(2025, 12, 2, hour: 1),
            pagesRead: 70
        )
        oldSession.readingAttempt = completedAttempt
        let activeSession = ReadingSession(
            book: book,
            startedAt: date(2026, 1, 7),
            endedAt: date(2026, 1, 7, hour: 1),
            pagesRead: 30
        )
        activeSession.readingAttempt = activeAttempt
        completedAttempt.sessionsSafe = [oldSession]
        activeAttempt.sessionsSafe = [activeSession]
        book.readingAttemptsSafe = [completedAttempt, activeAttempt]
        book.readingSessionsSafe = [oldSession, activeSession]

        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(book: book)

        #expect(snapshot.pageCount == 300)
        #expect(snapshot.pagesReadTotal == 30)
        let progressFraction = snapshot.readingProgressFraction ?? -1
        #expect(abs(progressFraction - 0.1) < 0.000_001)
        #expect(snapshot.lastSessionAt == date(2026, 1, 7))
        #expect(snapshot.hasCover)
        #expect(snapshot.coverRevision > 0)
        #expect(snapshot.hasUserRating)
        #expect(snapshot.isRereading)
        #expect(snapshot.completedReadingAttemptCount == 1)
        #expect(snapshot.currentReadingAttemptDisplayName == "2. Durchgang")
        #expect(snapshot.collectionNames == ["Favorites"])
    }

    @Test func sourceSignatureChangesForSmartShelfRelevantSnapshotMutations() {
        let base = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            id: fixedID(1),
            title: "Alpha",
            createdAt: date(2026, 1, 1),
            statusRawValue: ReadingStatus.reading.rawValue,
            tags: ["Crime"],
            hasNotes: false,
            pageCount: 300,
            pagesReadTotal: 30,
            readingProgressFraction: 0.1,
            lastSessionAt: date(2026, 1, 7),
            hasCover: true,
            coverRevision: 100,
            hasUserRating: false,
            userRatingAverage1: nil,
            isRereading: false,
            completedReadingAttemptCount: 0
        )

        let original = LibraryView.LibrarySourceSnapshot.computeSignature(snapshot: [base])

        #expect(original != signature(mutating: base, pageCount: 320))
        #expect(original != signature(mutating: base, pagesReadTotal: 45, readingProgressFraction: 0.15))
        #expect(original != signature(mutating: base, lastSessionAt: date(2026, 1, 8)))
        #expect(original != signature(mutating: base, hasCover: false, coverRevision: 0))
        #expect(original != signature(mutating: base, hasUserRating: true, userRatingAverage1: 4.5))
        #expect(original != signature(mutating: base, isRereading: true, completedReadingAttemptCount: 1, currentReadingAttemptDisplayName: "2. Durchgang"))
    }

    private func signature(
        mutating snapshot: LibraryView.LibrarySourceSnapshot.BookSnapshot,
        pageCount: Int? = nil,
        pagesReadTotal: Int? = nil,
        readingProgressFraction: Double? = nil,
        lastSessionAt: Date? = nil,
        hasCover: Bool? = nil,
        coverRevision: Int? = nil,
        hasUserRating: Bool? = nil,
        userRatingAverage1: Double? = nil,
        isRereading: Bool? = nil,
        completedReadingAttemptCount: Int? = nil,
        currentReadingAttemptDisplayName: String? = nil
    ) -> Int {
        let mutated = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            id: snapshot.id,
            title: snapshot.title,
            author: snapshot.author,
            createdAt: snapshot.createdAt,
            statusRawValue: snapshot.statusRawValue,
            tags: snapshot.tags,
            hasNotes: snapshot.hasNotes,
            isbn13: snapshot.isbn13,
            readFrom: snapshot.readFrom,
            readTo: snapshot.readTo,
            pageCount: pageCount ?? snapshot.pageCount,
            pagesReadTotal: pagesReadTotal ?? snapshot.pagesReadTotal,
            readingProgressFraction: readingProgressFraction ?? snapshot.readingProgressFraction,
            lastSessionAt: lastSessionAt ?? snapshot.lastSessionAt,
            hasCover: hasCover ?? snapshot.hasCover,
            coverRevision: coverRevision ?? snapshot.coverRevision,
            hasUserRating: hasUserRating ?? snapshot.hasUserRating,
            userRatingAverage1: userRatingAverage1 ?? snapshot.userRatingAverage1,
            isRereading: isRereading ?? snapshot.isRereading,
            completedReadingAttemptCount: completedReadingAttemptCount ?? snapshot.completedReadingAttemptCount,
            currentReadingAttemptDisplayName: currentReadingAttemptDisplayName ?? snapshot.currentReadingAttemptDisplayName,
            collectionNames: snapshot.collectionNames,
            searchTokens: snapshot.searchTokens
        )
        return LibraryView.LibrarySourceSnapshot.computeSignature(snapshot: [mutated])
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}
