import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingAttemptBookDetailUXTests {

    @Test @MainActor func finishedBookStartsNewRereadAttemptWithoutDestroyingCompletion() throws {
        let firstStart = Date(timeIntervalSince1970: 1_000)
        let firstFinish = Date(timeIntervalSince1970: 2_000)
        let rereadStart = Date(timeIntervalSince1970: 3_000)
        let book = Book(title: "Dune", status: .finished)
        book.pageCount = 400
        book.readFrom = firstStart
        book.readTo = firstFinish
        book.userRatingPlot = 5

        let completed = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .finished,
            startedAt: firstStart,
            finishedAt: firstFinish,
            pageCountSnapshot: 400
        )
        book.readingAttemptsSafe = [completed]

        let active = ReadingAttemptSessionCoordinator.startNewRereadAttempt(
            for: book,
            startedAt: rereadStart,
            now: rereadStart,
            insertAttempt: { _ in }
        )

        #expect(book.status == .reading)
        #expect(book.readFrom == firstStart)
        #expect(book.readTo == firstFinish)
        #expect(book.userRatingPlot == 5)
        #expect(book.completedReadingAttemptCount == 1)
        #expect(book.isRereading)
        #expect(active.sequenceNumber == 2)
        #expect(active.startedAt == rereadStart)
        #expect(active.status == .active)
    }

    @Test @MainActor func activeRereadProgressUsesOnlyActiveAttemptSessions() throws {
        let book = Book(title: "Again", status: .reading)
        book.pageCount = 100

        let completed = ReadingAttempt(book: book, sequenceNumber: 1, status: .finished)
        let active = ReadingAttempt(book: book, sequenceNumber: 2, status: .active)
        book.readingAttemptsSafe = [completed, active]

        let oldSession = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_100),
            pagesRead: 100,
            note: nil
        )
        oldSession.readingAttempt = completed
        completed.addSessionIfNeeded(oldSession)

        let activeSession = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 2_000),
            endedAt: Date(timeIntervalSince1970: 2_100),
            pagesRead: 30,
            note: nil
        )
        activeSession.readingAttempt = active
        active.addSessionIfNeeded(activeSession)
        book.readingSessionsSafe = [oldSession, activeSession]

        let progressSessions = ReadingAttemptSessionCoordinator.progressSessions(
            for: book,
            allSessions: book.readingSessionsSafe
        )

        #expect(progressSessions.map(\.id) == [activeSession.id])
        #expect(ReadingSessionLogging.pagesReadTotal(in: progressSessions) == 30)
        #expect(ReadingAttemptSessionCoordinator.currentRemainingPages(for: book, allSessions: book.readingSessionsSafe) == 70)
    }

    @Test @MainActor func sessionIsAssignedToActiveAttemptAndCanFinishThatAttempt() throws {
        let book = Book(title: "Finish Again", status: .reading)
        book.pageCount = 40
        let active = ReadingAttempt(
            book: book,
            sequenceNumber: 2,
            status: .active,
            startedAt: Date(timeIntervalSince1970: 1_000),
            pageCountSnapshot: 40
        )
        book.readingAttemptsSafe = [
            ReadingAttempt(book: book, sequenceNumber: 1, status: .finished),
            active
        ]

        let existing = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 1_100),
            endedAt: Date(timeIntervalSince1970: 1_200),
            pagesRead: 15,
            note: nil
        )
        existing.readingAttempt = active
        active.addSessionIfNeeded(existing)
        book.readingSessionsSafe = [existing]

        let timing = ReadingSessionLogging.Timing(
            startedAt: Date(timeIntervalSince1970: 1_300),
            endedAt: Date(timeIntervalSince1970: 1_400)
        )
        let result = ReadingSessionLogging.plan(
            bookState: ReadingSessionLogging.BookState(book: book),
            existingSessions: ReadingAttemptSessionCoordinator.sessions(for: active, allSessions: book.readingSessionsSafe),
            timing: timing,
            pages: 25,
            note: "Finale"
        )

        guard case .success(let plan) = result else {
            #expect(Bool(false))
            return
        }
        plan.apply(to: book)
        let newSession = plan.makeSession(book: book)
        ReadingAttemptSessionCoordinator.attach(
            session: newSession,
            to: active,
            plan: plan,
            book: book,
            now: timing.endedAt
        )

        #expect(plan.didMarkFinished)
        #expect(book.status == .finished)
        #expect(book.readTo == timing.endedAt)
        #expect(active.status == .finished)
        #expect(active.finishedAt == timing.endedAt)
        #expect(newSession.readingAttempt?.id == active.id)
        #expect(active.sessionsSafe.map(\.id).contains(newSession.id))
    }

    @Test @MainActor func supplementingFinishedBookDoesNotCreateNewAttemptOrDestroyCompletion() throws {
        let firstStart = Date(timeIntervalSince1970: 1_000)
        let firstFinish = Date(timeIntervalSince1970: 2_000)
        let book = Book(title: "Supplement", status: .finished)
        book.pageCount = 100
        book.readFrom = firstStart
        book.readTo = firstFinish

        let completed = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .finished,
            startedAt: firstStart,
            finishedAt: firstFinish,
            pageCountSnapshot: 100
        )
        book.readingAttemptsSafe = [completed]

        let oldSession = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 1_500),
            endedAt: Date(timeIntervalSince1970: 1_600),
            pagesRead: 100,
            note: nil
        )
        oldSession.readingAttempt = completed
        completed.addSessionIfNeeded(oldSession)
        book.readingSessionsSafe = [oldSession]

        let timing = ReadingSessionLogging.Timing(
            startedAt: Date(timeIntervalSince1970: 3_000),
            endedAt: Date(timeIntervalSince1970: 3_100)
        )
        let result = ReadingSessionLogging.plan(
            bookState: ReadingSessionLogging.BookState(book: book),
            existingSessions: book.readingSessionsSafe,
            timing: timing,
            pages: 10,
            note: "Bookclub",
            allowsFinishedBookSupplement: true
        )

        guard case .success(let plan) = result else {
            #expect(Bool(false))
            return
        }
        plan.apply(to: book)
        let session = plan.makeSession(book: book)
        ReadingAttemptSessionCoordinator.attach(
            session: session,
            to: nil,
            plan: plan,
            book: book,
            now: timing.endedAt
        )

        #expect(plan.isLegacySupplement)
        #expect(plan.didMarkFinished == false)
        #expect(book.status == .finished)
        #expect(book.readFrom == firstStart)
        #expect(book.readTo == firstFinish)
        #expect(book.activeReadingAttempt == nil)
        #expect(book.completedReadingAttemptCount == 1)
        #expect(session.readingAttempt == nil)
    }

    @Test @MainActor func groupingShowsActiveAttemptFirstAndLegacySessionsLast() {
        let book = Book(title: "Grouped", status: .reading)
        let completed = ReadingAttempt(book: book, sequenceNumber: 1, status: .finished)
        let active = ReadingAttempt(book: book, sequenceNumber: 2, status: .active)
        book.readingAttemptsSafe = [completed, active]

        let completedSession = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_100),
            pagesRead: 50,
            note: nil
        )
        completedSession.readingAttempt = completed
        completed.addSessionIfNeeded(completedSession)

        let activeSession = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 2_000),
            endedAt: Date(timeIntervalSince1970: 2_100),
            pagesRead: 20,
            note: nil
        )
        activeSession.readingAttempt = active
        active.addSessionIfNeeded(activeSession)

        let legacySession = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 3_000),
            endedAt: Date(timeIntervalSince1970: 3_100),
            pagesRead: nil,
            note: "Alt"
        )

        let groups = ReadingSessionGrouping.makeGroups(
            book: book,
            sessions: [completedSession, activeSession, legacySession]
        )

        #expect(groups.map(\.title) == ["2. Durchgang · läuft", "1. Durchgang", "Nicht zugeordnet"])
        #expect(groups[0].sessions.map(\.id) == [activeSession.id])
        #expect(groups[1].sessions.map(\.id) == [completedSession.id])
        #expect(groups[2].sessions.map(\.id) == [legacySession.id])
    }
}
