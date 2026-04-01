import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryDerivedStateCoordinatorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func makeSource(
        _ books: [LibraryView.LibrarySourceSnapshot.BookSnapshot]
    ) -> LibraryView.LibrarySourceSnapshot {
        LibraryView.LibrarySourceSnapshot(
            signature: LibraryView.LibrarySourceSnapshot.computeSignature(snapshot: books),
            books: books
        )
    }

    @Test func resolvesOnlyWhenTokenChanges() {
        var coordinator = LibraryView.LibraryDerivedStateCoordinator()
        let source = makeSource([
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                title: "Alpha",
                createdAt: date(2026, 1, 1)
            )
        ])
        let input = LibraryView.LibraryDerivedStateBuilder.makeInput(
            searchText: "",
            selectedStatus: nil,
            selectedTag: nil,
            onlyWithNotes: false,
            sortField: .createdAt,
            sortAscending: false,
            buildsAlphaSections: false
        )
        let token = LibraryView.LibraryDerivedStateBuilder.makeInputToken(source: source, input: input)
        var buildCount = 0

        coordinator.resolveIfNeeded(for: token, source: source, input: input) { source, input in
            buildCount += 1
            return LibraryView.LibraryDerivedStateBuilder.makeDerivedState(source: source, input: input)
        }
        coordinator.resolveIfNeeded(for: token, source: source, input: input) { source, input in
            buildCount += 1
            return LibraryView.LibraryDerivedStateBuilder.makeDerivedState(source: source, input: input)
        }

        #expect(buildCount == 1)
        #expect(coordinator.isResolved(for: token))
    }

    @Test func keepsLastStableStateUntilNewTokenIsResolved() {
        var coordinator = LibraryView.LibraryDerivedStateCoordinator()
        let source = makeSource([
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                title: "Alpha",
                createdAt: date(2026, 1, 1)
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                title: "Beta",
                createdAt: date(2026, 1, 2)
            )
        ])
        let originalInput = LibraryView.LibraryDerivedStateBuilder.makeInput(
            searchText: "",
            selectedStatus: nil,
            selectedTag: nil,
            onlyWithNotes: false,
            sortField: .title,
            sortAscending: true,
            buildsAlphaSections: false
        )
        let originalToken = LibraryView.LibraryDerivedStateBuilder.makeInputToken(source: source, input: originalInput)
        coordinator.resolveIfNeeded(for: originalToken, source: source, input: originalInput)

        let filteredInput = LibraryView.LibraryDerivedStateBuilder.makeInput(
            searchText: "Beta",
            selectedStatus: nil,
            selectedTag: nil,
            onlyWithNotes: false,
            sortField: .title,
            sortAscending: true,
            buildsAlphaSections: false
        )
        let filteredToken = LibraryView.LibraryDerivedStateBuilder.makeInputToken(source: source, input: filteredInput)

        let displayedBeforeResolve = coordinator.displayState(for: filteredToken)

        #expect(displayedBeforeResolve.token == originalToken)
        #expect(displayedBeforeResolve.displayedBookIDs.count == 2)

        coordinator.resolveIfNeeded(for: filteredToken, source: source, input: filteredInput)
        let displayedAfterResolve = coordinator.displayState(for: filteredToken)

        #expect(displayedAfterResolve.token == filteredToken)
        #expect(displayedAfterResolve.displayedBookIDs.count == 1)
    }

    @Test func resolvingEmptySourceProducesEmptyStableState() {
        var coordinator = LibraryView.LibraryDerivedStateCoordinator()
        let source = makeSource([])
        let input = LibraryView.LibraryDerivedStateBuilder.makeInput(
            searchText: "",
            selectedStatus: nil,
            selectedTag: nil,
            onlyWithNotes: false,
            sortField: .createdAt,
            sortAscending: false,
            buildsAlphaSections: false
        )
        let token = LibraryView.LibraryDerivedStateBuilder.makeInputToken(source: source, input: input)

        coordinator.resolveIfNeeded(for: token, source: source, input: input)

        let displayedState = coordinator.displayState(for: token)
        #expect(displayedState.displayedBookIDs.isEmpty)
        #expect(displayedState.counts == .zero)
        #expect(displayedState.token == token)
    }
}
