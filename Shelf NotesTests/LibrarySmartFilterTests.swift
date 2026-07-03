import Foundation
import Testing
@testable import Shelf_Notes

struct LibrarySmartFilterTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    @Test func smartFiltersExposeStableTitlesAndSymbols() {
        #expect(LibraryView.LibrarySmartFilter.withoutCover.title == "Ohne Cover")
        #expect(LibraryView.LibrarySmartFilter.withoutTags.systemImage == "tag")
        #expect(LibraryView.LibrarySmartFilter.longInactive.id == "longInactive")
    }

    @Test func longInactiveRequiresReadingStatusAndCutoff() {
        let oldReading = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Old Reading",
            createdAt: date(2026, 1, 1),
            statusRawValue: ReadingStatus.reading.rawValue,
            lastSessionAt: date(2026, 1, 10)
        )
        let oldFinished = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Old Finished",
            createdAt: date(2026, 1, 1),
            statusRawValue: ReadingStatus.finished.rawValue,
            lastSessionAt: date(2026, 1, 10)
        )

        #expect(LibraryView.LibrarySmartFilter.longInactive.matches(oldReading, longInactiveCutoff: date(2026, 2, 1)))
        #expect(LibraryView.LibrarySmartFilter.longInactive.matches(oldReading, longInactiveCutoff: nil) == false)
        #expect(LibraryView.LibrarySmartFilter.longInactive.matches(oldFinished, longInactiveCutoff: date(2026, 2, 1)) == false)
    }

    @Test func rereadsIncludeActiveAndCompletedRereadHistory() {
        let activeReread = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Active reread",
            isRereading: true,
            completedReadingAttemptCount: 1
        )
        let completedReread = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Completed reread",
            isRereading: false,
            completedReadingAttemptCount: 2
        )
        let firstRead = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "First read",
            isRereading: false,
            completedReadingAttemptCount: 1
        )

        #expect(LibraryView.LibrarySmartFilter.rereads.matches(activeReread, longInactiveCutoff: nil))
        #expect(LibraryView.LibrarySmartFilter.rereads.matches(completedReread, longInactiveCutoff: nil))
        #expect(LibraryView.LibrarySmartFilter.rereads.matches(firstRead, longInactiveCutoff: nil) == false)
    }
}
