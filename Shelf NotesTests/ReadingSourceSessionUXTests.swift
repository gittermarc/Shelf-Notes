import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingSourceSessionUXTests {
    @Test @MainActor func newRereadStoresSelectedSourceWithoutChangingCompletedAttempt() {
        let book = Book(title: "Again", status: .finished)
        book.pageCount = 320
        let completed = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .finished,
            readingMedium: .physical,
            defaultProvider: .none,
            progressUnit: .pages
        )
        book.readingAttemptsSafe = [completed]
        let source = ReadingSourceDraft(selection: .kindle).sessionSource(
            origin: .legacy,
            bookPageCount: book.pageCount
        )

        let active = ReadingAttemptSessionCoordinator.startNewRereadAttempt(
            for: book,
            startedAt: Date(timeIntervalSince1970: 20_000),
            now: Date(timeIntervalSince1970: 20_000),
            source: source,
            insertAttempt: { _ in }
        )

        #expect(completed.readingMedium == .physical)
        #expect(completed.defaultProvider == .none)
        #expect(completed.progressUnit == .pages)
        #expect(active.readingMedium == .ebook)
        #expect(active.defaultProvider == .kindle)
        #expect(active.progressUnit == .percentage)
        #expect(active.totalValueSnapshot == 100)
    }

    @Test @MainActor func existingActiveRereadKeepsItsOriginalSource() {
        let book = Book(title: "Already Active", status: .reading)
        let active = ReadingAttempt(
            book: book,
            sequenceNumber: 2,
            status: .active,
            readingMedium: .ebook,
            defaultProvider: .kindle,
            progressUnit: .percentage,
            totalValueSnapshot: 100
        )
        book.readingAttemptsSafe = [active]

        let returned = ReadingAttemptSessionCoordinator.startNewRereadAttempt(
            for: book,
            startedAt: Date(timeIntervalSince1970: 20_100),
            now: Date(timeIntervalSince1970: 20_100),
            source: ReadingSourceDraft(selection: .physical).sessionSource(
                origin: .legacy,
                bookPageCount: 300
            ),
            insertAttempt: { _ in
                Issue.record("An existing active reread must not create another attempt.")
            }
        )

        #expect(returned.id == active.id)
        #expect(active.readingMedium == .ebook)
        #expect(active.defaultProvider == .kindle)
        #expect(active.progressUnit == .percentage)
        #expect(active.totalValueSnapshot == 100)
        #expect(book.readingAttemptsSafe.count == 1)
    }

    @Test @MainActor func sessionContextUsesAttemptSourceForQuickLogAndTimer() {
        let book = Book(title: "Digital", status: .reading)
        let attempt = ReadingAttempt(
            book: book,
            status: .active,
            readingMedium: .ebook,
            defaultProvider: .appleBooks,
            progressUnit: .percentage,
            totalValueSnapshot: 100
        )
        book.readingAttemptsSafe = [attempt]
        let wrongRequestedSource = ReadingSessionSource(
            medium: .physical,
            provider: .none,
            progressUnit: .pages,
            origin: .quickLog,
            totalValue: 400
        )

        let context = ReadingSessionContext.resolved(
            readingAttempt: attempt,
            requestedSource: wrongRequestedSource
        )

        #expect(context.medium == .ebook)
        #expect(context.provider == .appleBooks)
        #expect(context.progressUnit == .percentage)
        #expect(context.totalValue == 100)
        #expect(context.origin == .quickLog)
    }

    @Test @MainActor func quickLogAndTimerBuildIdenticalProgressLogic() throws {
        let book = Book(title: "Same Rules", status: .reading)
        let attempt = ReadingAttempt(
            book: book,
            status: .active,
            readingMedium: .ebook,
            defaultProvider: .googleBooks,
            progressUnit: .percentage,
            totalValueSnapshot: 100
        )
        book.readingAttemptsSafe = [attempt]
        let event = ReadingProgressEvent(
            book: book,
            readingAttempt: attempt,
            occurredAt: Date(timeIntervalSince1970: 21_000),
            medium: .ebook,
            provider: .googleBooks,
            progressUnit: .percentage,
            nativeValue: 25,
            totalValue: 100,
            normalizedProgress: 0.25,
            origin: .legacy,
            deduplicationKey: "baseline"
        )
        attempt.progressEventsSafe = [event]
        book.readingProgressEventsSafe = [event]
        var state = ReadingProgressInputState()
        state.percentageText = "40"
        let occurredAt = Date(timeIntervalSince1970: 22_000)

        let quick = ReadingSessionMutationService.makeProgressInputContext(
            book: book,
            allSessions: [],
            origin: .quickLog
        )
        let timer = ReadingSessionMutationService.makeProgressInputContext(
            book: book,
            allSessions: [],
            origin: .timer
        )
        let quickSubmission = try ReadingProgressInputBuilder.makeSubmission(
            state: state,
            configuration: quick.configuration,
            occurredAt: occurredAt
        ).get()
        let timerSubmission = try ReadingProgressInputBuilder.makeSubmission(
            state: state,
            configuration: timer.configuration,
            occurredAt: occurredAt
        ).get()

        #expect(quick.configuration == timer.configuration)
        #expect(quickSubmission == timerSubmission)
        #expect(quick.source.origin == .quickLog)
        #expect(timer.source.origin == .timer)
        #expect(quick.source.medium == timer.source.medium)
        #expect(quick.source.provider == timer.source.provider)
        #expect(quick.source.progressUnit == timer.source.progressUnit)
    }

    @Test @MainActor func existingLegacyAttemptKeepsPhysicalPageExperience() {
        let book = Book(title: "Legacy", status: .reading)
        book.pageCount = 200
        let attempt = ReadingAttempt(book: book, status: .active)
        book.readingAttemptsSafe = [attempt]

        let context = ReadingSessionMutationService.makeProgressInputContext(
            book: book,
            allSessions: [],
            origin: .quickLog
        )

        #expect(context.source.medium == .physical)
        #expect(context.source.provider == .none)
        #expect(context.source.progressUnit == .pages)
        #expect(context.configuration.sourceTitle == "Physisches Buch")
        #expect(context.configuration.remainingPages == 200)
    }
}
