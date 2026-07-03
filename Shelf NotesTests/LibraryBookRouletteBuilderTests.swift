import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryBookRouletteBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    @Test func rouletteUsesOnlyToReadBooksWithTitles() {
        let stack = makeBook(
            id: fixedID(1),
            title: "Stack Book",
            status: .toRead,
            createdAt: date(2026, 2, 1)
        )
        let reading = makeBook(
            id: fixedID(2),
            title: "Current Book",
            status: .reading,
            createdAt: date(2026, 2, 2)
        )
        let finished = makeBook(
            id: fixedID(3),
            title: "Finished Book",
            status: .finished,
            createdAt: date(2026, 2, 3)
        )
        let untitled = makeBook(
            id: fixedID(4),
            title: "   ",
            status: .toRead,
            createdAt: date(2026, 2, 4)
        )

        let roulette = LibraryView.LibraryBookRouletteBuilder.makeRoulette(
            books: [reading, stack, finished, untitled]
        )

        #expect(roulette.candidateIDs == [stack.id])
    }

    @Test func rouletteRespectsTagFilter() {
        let crime = makeBook(
            id: fixedID(1),
            title: "Crime Stack",
            tags: ["#Crime", "Noir"],
            createdAt: date(2026, 2, 1)
        )
        let history = makeBook(
            id: fixedID(2),
            title: "History Stack",
            tags: ["History"],
            createdAt: date(2026, 2, 2)
        )

        let roulette = LibraryView.LibraryBookRouletteBuilder.makeRoulette(
            books: [history, crime],
            selectedTag: "crime"
        )

        #expect(roulette.candidateIDs == [crime.id])
    }

    @Test func rouletteRespectsCollectionFilter() {
        let vacation = makeBook(
            id: fixedID(1),
            title: "Vacation Stack",
            collectionNames: ["Urlaub"],
            createdAt: date(2026, 2, 1)
        )
        let backlog = makeBook(
            id: fixedID(2),
            title: "Backlog Stack",
            collectionNames: ["Backlog"],
            createdAt: date(2026, 2, 2)
        )

        let roulette = LibraryView.LibraryBookRouletteBuilder.makeRoulette(
            books: [backlog, vacation],
            selectedCollectionName: "urlaub"
        )

        #expect(roulette.candidateIDs == [vacation.id])
    }

    @Test func rouletteCandidatesAreStableAndLimited() {
        let oldest = makeBook(
            id: fixedID(1),
            title: "Oldest",
            createdAt: date(2026, 1, 1)
        )
        let newest = makeBook(
            id: fixedID(2),
            title: "Newest",
            createdAt: date(2026, 1, 3)
        )
        let middle = makeBook(
            id: fixedID(3),
            title: "Middle",
            createdAt: date(2026, 1, 2)
        )

        let roulette = LibraryView.LibraryBookRouletteBuilder.makeRoulette(
            books: [oldest, newest, middle],
            candidateLimit: 2
        )

        #expect(roulette.candidateIDs == [newest.id, middle.id])
    }

    @Test func drawCandidateIsDeterministicAndAvoidsImmediateRepeat() {
        let first = makeBook(id: fixedID(1), title: "First", createdAt: date(2026, 1, 3))
        let second = makeBook(id: fixedID(2), title: "Second", createdAt: date(2026, 1, 2))
        let third = makeBook(id: fixedID(3), title: "Third", createdAt: date(2026, 1, 1))
        let roulette = LibraryView.LibraryBookRouletteBuilder.makeRoulette(books: [third, second, first])

        let initial = roulette.drawCandidate { _ in 0 }
        let next = roulette.drawCandidate(excluding: initial?.id) { _ in 0 }

        #expect(initial?.id == first.id)
        #expect(next?.id != initial?.id)
        #expect(next?.id == second.id)
    }

    @Test func drawCandidateKeepsSingleCandidateAvailable() {
        let onlyBook = makeBook(id: fixedID(1), title: "Only", createdAt: date(2026, 1, 1))
        let roulette = LibraryView.LibraryBookRouletteBuilder.makeRoulette(books: [onlyBook])

        let drawn = roulette.drawCandidate(excluding: onlyBook.id) { _ in 0 }

        #expect(drawn?.id == onlyBook.id)
    }

    private func makeBook(
        id: UUID,
        title: String,
        status: ReadingStatus = .toRead,
        tags: [String] = [],
        collectionNames: [String] = [],
        createdAt: Date
    ) -> LibraryView.LibrarySourceSnapshot.BookSnapshot {
        LibraryView.LibrarySourceSnapshot.BookSnapshot(
            id: id,
            title: title,
            createdAt: createdAt,
            statusRawValue: status.rawValue,
            tags: tags,
            collectionNames: collectionNames
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}
