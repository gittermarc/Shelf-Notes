import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryBookPresentationTests {
    @Test func readingBookBuildsFormattedProgressTexts() {
        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            id: fixedID(1),
            title: "Dune",
            statusRawValue: ReadingStatus.reading.rawValue,
            pageCount: 300,
            pagesReadTotal: 126,
            readingProgressFraction: 0.42,
            lastSessionAt: date(2026, 1, 7)
        )

        let presentation = LibraryBookPresentation(snapshot: snapshot)

        #expect(presentation.id == snapshot.id)
        #expect(presentation.shouldShowReadingProgress)
        #expect(presentation.progressFraction == 0.42)
        #expect(presentation.progressText == "42 %")
        #expect(presentation.pageProgressText == "126 von 300 Seiten")
        #expect(presentation.remainingPagesText == "noch 174 Seiten")
        #expect(presentation.lastActivityText != nil)
    }

    @Test func missingPageCountDoesNotCreatePageOrPercentageFallbacks() {
        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Unknown Pages",
            statusRawValue: ReadingStatus.reading.rawValue,
            pageCount: nil,
            pagesReadTotal: 42,
            readingProgressFraction: nil
        )

        let presentation = LibraryBookPresentation(snapshot: snapshot)

        #expect(presentation.shouldShowReadingProgress == false)
        #expect(presentation.progressFraction == nil)
        #expect(presentation.progressText == nil)
        #expect(presentation.pageProgressText == nil)
        #expect(presentation.remainingPagesText == nil)
    }

    @Test func finishedBookDoesNotShowActiveProgressCue() {
        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Finished",
            statusRawValue: ReadingStatus.finished.rawValue,
            pageCount: 300,
            pagesReadTotal: 300,
            readingProgressFraction: 1.0
        )

        let presentation = LibraryBookPresentation(snapshot: snapshot)

        #expect(presentation.progressText == "100 %")
        #expect(presentation.pageProgressText == "300 von 300 Seiten")
        #expect(presentation.remainingPagesText == nil)
        #expect(presentation.shouldShowReadingProgress == false)
    }

    @Test func rereadHintUsesPreparedAttemptDisplayName() {
        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Again",
            statusRawValue: ReadingStatus.reading.rawValue,
            pageCount: 200,
            pagesReadTotal: 50,
            readingProgressFraction: 0.25,
            isRereading: true,
            completedReadingAttemptCount: 1,
            currentReadingAttemptDisplayName: "2. Durchgang"
        )

        let presentation = LibraryBookPresentation(snapshot: snapshot)

        #expect(presentation.rereadBadgeText == "2. Durchgang")
        #expect(presentation.accessibilitySummary.contains("2. Durchgang"))
    }

    @Test func pageTextClampsReadPagesToKnownPageCount() {
        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Overread",
            statusRawValue: ReadingStatus.reading.rawValue,
            pageCount: 100,
            pagesReadTotal: 140,
            readingProgressFraction: 1.2
        )

        let presentation = LibraryBookPresentation(snapshot: snapshot)

        #expect(presentation.progressFraction == 1.0)
        #expect(presentation.progressText == "100 %")
        #expect(presentation.pageProgressText == "100 von 100 Seiten")
        #expect(presentation.remainingPagesText == nil)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}
